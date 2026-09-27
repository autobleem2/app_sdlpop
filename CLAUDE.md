# app_sdlpop - developer context

**SDLPoP** (the open-source port of Prince of Persia, 1989) packaged as an AutoBleem App: `Apps/sdlpop/`, Store id
`app/sdlpop`, one zip per platform (`dist/sdlpop-<key>-<version>.zip`) in the multi-platform App format (the
launcher's `docs/app-format-plan.md`). Started 2026-09-25, the second third-party App port (autobleem-main
`docs/decisions.md`, "Third-party App ports"), after `app_opentyrian` - whose CLAUDE.md is the template this
one follows. It replaces the RetroBoot 1.2 binary (genderbent's 2019 PSC build, psc only) in the Store.

## The rules this repository follows (the owner's, 2026-09-25)

- **A patch over a pinned upstream submodule**, never a fork: `upstream/SDLPoP` is at **v1.24-RC** (2025-04-20;
  the owner's choice over v1.23 and master). `ci/build.sh` copies it into `build_<key>/` and applies
  `patches/SDLPoP/*.patch` there. Make a patch by editing the submodule, `git -C upstream/SDLPoP diff >
  patches/SDLPoP/NNNN-what.patch`, and checking the submodule out clean again.
- **No libraries of its own**: SDLPoP needs SDL2 and SDL2_image only, both the launcher's (the console's
  `/tmp/lib`, the Windows product's folder) or the system's (the Pis, the PC stick). `lib/<key>/` is absent and
  `app.ini` has no `Lib=`. `tools/check_needed.sh` fails the build on anything else.
- **The game data ships as upstream ships it**: `upstream/SDLPoP/data` is the 1989 DOS game's (Mechner's /
  Ubisoft's), with no licence of its own; the owner decided to ship it like SDLPoP does (see `LICENSE`).
- **`VirtualPad=true`**, no pad patch: SDLPoP reads the GameController API, and its own mapping is the 2020
  port's layout (A down, Y up, X Shift, Start and Back the pause menu).

## Layout

| path | what |
|---|---|
| `upstream/SDLPoP` | the pinned upstream source (submodule) |
| `patches/SDLPoP/0001-psc-settings.patch` | `SDLPoP.ini`: the 2020 PSC port's settings - full screen at 1280x720, `use_correct_aspect_ratio`, `scaling_type = fuzzy`, both stick axes, no info screen |
| `resources/` | `app.ini` (`Exec=bin/{key}/prince`, no `Args`, no `Lib`, no `Startup=` - the launcher's `rc/app_run.sh` starts it in the App's folder), `readme.txt`, `icon.png` (the 2020 package's) |
| `ci/build.sh` | `native|psc|rpi|rpi64|pcusb|win|all` in the autobleem-build image: upstream's `src/Makefile` with `CC`, `BIN`, `CFLAGS` and `LIBS` on its command line; Windows adds upstream's `icon.rc` |
| `/opt/ab/tools/check_psc_binary.sh`, `/opt/ab/tools/check_needed.sh` (autobleem-build image) | no longer vendored (APPS-6) - as in app_opentyrian (the latter allows the launcher's whole SDL2 family on Windows) |
| `tools/store_item.py` | a package -> `dist/store/<key>/` with `sdlpop.item.json` and `sdlpop.png`, for autobleem-repo's `repo_publish.sh store <key> dist/store/<key>/*` |

## Things to know

- **Where things are at run time**: SDLPoP looks for every file in the working directory first, then next to
  the program - the launcher starts it in `Apps/sdlpop/`, so `data/`, `SDLPoP.ini`, the saves (`PRINCE.SAV`,
  `QUICKSAVE.SAV`), the hall of fame and `SDLPoP.cfg` (the pause menu's settings, which win over the ini) are
  all in the App's folder. A Store update lays the package over it and leaves the saves and `SDLPoP.cfg` alone.
- **SDL**: nothing newer than SDL 2.0.5 is used unguarded (`SDL_RenderSetIntegerScale` is behind
  `SDL_VERSION_ATLEAST`), so the console's 2.0.14 runs it.
- **Windows**: SDLPoP includes `<SDL2/SDL.h>`, so the MinGW build needs both `/opt/mingw-sdl2/include` and
  `.../include/SDL2`. Run on the dev PC on 2026-09-25 with only the Windows product's official SDL DLLs on PATH
  and the App folder as the working directory: it starts full screen, window title "Prince of Persia (SDLPoP)
  v1.24 RC".
- **Line endings**: the submodule must be checked out with LF (`git -C upstream/SDLPoP config core.autocrlf
  false`, then re-checkout) or the patch does not apply on a Windows checkout synced to the server.
- **Build on the server**: sync with MSYS2's rsync (excluding `/build_*`, `/dist`), then
  `docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all`.
- **Releases**: a `v<upstream>-<n>` tag (`v1.24-RC-1`) builds a stable GitHub release (only lower-case
  alpha/beta/rc/pre suffixes make a pre-release - upstream's `RC` does not); `master` follows the released
  commit. The Store gets it by hand: `gh release download <tag>`, `tools/store_item.py` per zip, then
  autobleem-repo's `repo_publish.sh store <key> dist/store/<key>/*`. v1.24-RC-1 went to all five catalogs on
  2026-09-25, replacing the RetroBoot build on psc.
- **Not yet run**: on a console, a Pi or the PC stick (the tester checklist, section 12).
