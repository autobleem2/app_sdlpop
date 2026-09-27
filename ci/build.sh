#!/usr/bin/env bash
# Builds the SDLPoP App in the autobleem-build image (ghcr.io/autobleem2/autobleem-build) and packages it:
#
#   ci/build.sh native                    a host build (build_native/)
#   ci/build.sh psc|rpi|rpi64|pcusb|win   a target, packed into dist/sdlpop-<key>-<version>.zip
#   ci/build.sh all                       every one of them
#
# What is ours and what is upstream's (CLAUDE.md): upstream/SDLPoP is a pinned submodule, never edited - each
# build copies it into build_<key>/ and applies patches/SDLPoP/*.patch there.
#
# A package is the App's folder as a stick has it - Apps/sdlpop/app.ini, the shared files (icon, readme,
# SDLPoP.ini, the game data, the docs) and bin/<key>/prince for its one platform - which is what the Store's
# AppInstaller lays over Apps/sdlpop/, keeping any other platform's bin/<key>/. SDLPoP needs SDL2 and
# SDL2_image only, and both are the launcher's (the console, Windows) or the system's (the Pis, the PC stick),
# so lib/<key>/ is empty. The version is app.ini's Version=, or AB_VERSION.
#
# On the build server: docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src \
#                          ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

APP=sdlpop
VERSION="${AB_VERSION:-$(sed -n 's/^Version=//p' resources/app.ini | tr -d '\r')}"
JOBS="${JOBS:-$(nproc)}"
PSC=${AB_PSC_TOOLCHAIN:-/opt/psc}
MINGW_SDL2=${AB_MINGW_SDL2:-/opt/mingw-sdl2}

banner() { printf '\n==== %s ====\n' "$*"; }

# ---------------------------------------------------------------------------------------------------------
# One target. The variables set by each target_* function:
#   CC, STRIP, CFLAGS_T      the compiler, its strip, the target's CPU flags
#   SDL_CFLAGS, SDL_LIBS     how to compile and link against SDL2 and SDL2_image
# ---------------------------------------------------------------------------------------------------------
pc_sdl() { # pc_sdl <pkg-config> [env...]: SDL_CFLAGS/SDL_LIBS for sdl2 + SDL2_image
    local pc="$1"
    SDL_CFLAGS=$("$pc" --cflags sdl2 SDL2_image)
    SDL_LIBS=$("$pc" --libs sdl2 SDL2_image)
}
target_native() {
    CC=gcc; STRIP=strip; CFLAGS_T="-O2"; EXE=prince
    pc_sdl pkg-config
}
target_psc() {
    # the console's gcc-6 against a Debian Stretch sysroot, and the launcher's SDL2 2.0.14 family
    # (/opt/psc/sdl2), which is what /tmp/lib holds on the console
    CC="$PSC/bin/armv8-sony-linux-gnueabihf-gcc"; STRIP="$PSC/bin/armv8-sony-linux-gnueabihf-strip"
    CFLAGS_T="-mfloat-abi=hard -march=armv8-a -mfpu=neon-vfpv4 -O2"; EXE=prince
    SDL_CFLAGS=$(PKG_CONFIG_LIBDIR="$PSC/sdl2/lib/pkgconfig" pkg-config --cflags sdl2 SDL2_image)
    SDL_LIBS=$(PKG_CONFIG_LIBDIR="$PSC/sdl2/lib/pkgconfig" pkg-config --libs sdl2 SDL2_image)
}
target_rpi() {
    CC=arm-linux-gnueabihf-gcc; STRIP=arm-linux-gnueabihf-strip
    CFLAGS_T="-mfloat-abi=hard -mfpu=neon-vfpv4 -march=armv7-a -O2"; EXE=prince
    pc_sdl arm-linux-gnueabihf-pkg-config
}
target_rpi64() {
    CC=aarch64-linux-gnu-gcc; STRIP=aarch64-linux-gnu-strip
    CFLAGS_T="-march=armv8-a -O2"; EXE=prince
    pc_sdl aarch64-linux-gnu-pkg-config
}
target_pcusb() {
    CC=i686-linux-gnu-gcc; STRIP=i686-linux-gnu-strip
    CFLAGS_T="-march=i686 -mtune=generic -D_FILE_OFFSET_BITS=64 -O2"; EXE=prince
    pc_sdl i386-linux-gnu-pkg-config
}
target_win() {
    # the official SDL2 mingw development packages (/opt/mingw-sdl2): the SDL2.dll and SDL2_image.dll the
    # Windows product ships next to the launcher, which puts its folder on an App's PATH
    CC=x86_64-w64-mingw32-gcc; STRIP=x86_64-w64-mingw32-strip; WINDRES=x86_64-w64-mingw32-windres
    CFLAGS_T="-O2"; EXE=prince.exe
    SDL_CFLAGS="-I$MINGW_SDL2/include -I$MINGW_SDL2/include/SDL2 -Dmain=SDL_main"
    SDL_LIBS="-L$MINGW_SDL2/lib -lmingw32 -lSDL2main -lSDL2 -lSDL2_image -mwindows"
}

build_target() { # build_target <key>
    local key="$1" dir="build_$1"
    banner "$key ($dir)"
    "target_$key"

    rm -rf "$dir"
    mkdir -p "$dir/Apps/$APP/bin/$key"
    cp -r upstream/SDLPoP "$dir/src"
    rm -rf "$dir/src/.git"
    for p in patches/SDLPoP/*.patch; do
        [ -f "$p" ] || continue
        echo "patch: $p"
        patch -d "$dir/src" -p1 --no-backup-if-mismatch < "$p"
    done

    # upstream's src/Makefile, told everything on its command line (its pkg-config calls answer about the
    # host; a command-line CFLAGS/LIBS replaces what it adds). It writes the program to the tree's root.
    local libs="$SDL_LIBS"
    if [ "$key" = win ]; then
        # the program's icon, from upstream's own resource script
        "$WINDRES" --include-dir "$dir/src/src" "$dir/src/src/icon.rc" -O coff -o "$dir/src/src/icon.o"
        libs="$ROOT/$dir/src/src/icon.o $libs"
    fi
    make -C "$dir/src/src" -j "$JOBS" CC="$CC" BIN="../$EXE" \
        CFLAGS="-std=c99 $CFLAGS_T $SDL_CFLAGS" LIBS="$libs"

    local stage="$dir/Apps/$APP"
    cp "$dir/src/$EXE" "$stage/bin/$key/"
    "$STRIP" "$stage/bin/$key/$EXE"
    stage_shared "$dir" "$stage"
}

stage_shared() { # stage_shared <build dir> <stage>: the files every platform's package carries
    local dir="$1" stage="$2"
    cp resources/app.ini resources/readme.txt resources/icon.png "$stage/"
    cp "$dir/src/COPYING" "$stage/COPYING.txt"
    cp "$dir/src/SDLPoP.ini" "$stage/"
    cp -r "$dir/src/data" "$dir/src/doc" "$dir/src/mods" "$stage/"
    sed -i "s/^Version=.*/Version=$VERSION/" "$stage/app.ini"
}

package() { # package <key>
    local key="$1" dir="build_$1"
    mkdir -p dist
    local zip="dist/$APP-$key-$VERSION.zip"
    rm -f "$zip"
    (cd "$dir" && python3 - "$ROOT/$zip" "$APP" <<'EOF'
import os, sys, zipfile
# every file under Apps/<app>, with its mode (the program stays executable where the filesystem keeps it)
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(os.path.join("Apps", sys.argv[2])):
        dirs.sort()
        for name in sorted(files):
            z.write(os.path.join(root, name))
EOF
    )
    ls -l "$zip"
}

check() { # check <key>: what the program needs, and that it is what the platform can load
    local key="$1" stage="build_$1/Apps/$APP"
    case "$key" in
        psc)
            file "$stage/bin/psc/prince" | grep -q 'ELF 32-bit LSB.*ARM'
            bash /opt/ab/tools/check_psc_binary.sh "$stage/bin/psc/prince" "$PSC" ;;
        rpi) file "$stage/bin/rpi/prince" | grep -q 'ELF 32-bit LSB.*ARM' ;;
        rpi64) file "$stage/bin/rpi64/prince" | grep -q 'ELF 64-bit LSB.*aarch64' ;;
        pcusb) file "$stage/bin/pcusb/prince" | grep -q 'ELF 32-bit LSB.*Intel 80386' ;;
        win) file "$stage/bin/win/prince.exe" | grep -q 'PE32+ executable.*x86-64' ;;
    esac
    # nothing but the base system and the SDL2 family
    bash /opt/ab/tools/check_needed.sh "$key" "$stage"
}

build_native() {
    build_target native
    local stage=build_native/Apps/$APP
    "$stage/bin/native/prince" --version
}

build_one() { # build_one <key>
    build_target "$1"
    check "$1"
    package "$1"
}

[ $# -gt 0 ] || { echo "usage: $0 native|psc|rpi|rpi64|pcusb|win|all" >&2; exit 2; }
for target in "$@"; do
    case "$target" in
        native) build_native ;;
        psc | rpi | rpi64 | pcusb | win) build_one "$target" ;;
        all) build_native; for k in psc rpi rpi64 pcusb win; do build_one "$k"; done ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
    esac
done
