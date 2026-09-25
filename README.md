# app_sdlpop

[SDLPoP](https://github.com/NagyD/SDLPoP) - the open-source port of Prince of Persia (1989) - packaged as an
[AutoBleem](https://github.com/autobleem2/autobleem) App for the PlayStation Classic, the Raspberry Pi, the
AutoBleem PC stick and Windows. Install it from the AutoBleem Store.

The upstream source is a pinned submodule; this repository holds only the build (`ci/build.sh`, run in the
[autobleem-build](https://github.com/autobleem2/autobleem-build) image), one patch (the PlayStation Classic port's
`SDLPoP.ini` settings: full screen, 4:3, smooth scaling) and the App's files.

```
git clone --recurse-submodules https://github.com/autobleem2/app_sdlpop
ci/build.sh all    # inside ghcr.io/autobleem2/autobleem-build
```

Controls (PlayStation Classic pad): D-pad move, Triangle jump/climb, Cross duck, Square step/grab/sword,
Start or Select the pause menu. Hold Start + Select to leave.

Licence: the build and patch GPL-3.0-or-later, SDLPoP GPL-3.0-or-later; the Prince of Persia game data is the
1989 game's, shipped as SDLPoP ships it (see `LICENSE`).
