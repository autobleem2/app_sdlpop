#!/usr/bin/env python3
"""Write the AutoBleem Store's descriptor for one platform's package (autobleem-repo CLAUDE.md, "The AutoBleem
Store's catalog"), next to the package and the picture, ready for `repo_publish.sh store <platform> ...`:

    tools/store_item.py dist/sdlpop-psc-1.24-RC-1.zip      -> dist/store/psc/sdlpop.item.json
                                                                        + sdlpop.png + the zip

The id is the same on every platform (app/sdlpop), so an installed App is updated in place.
Only the standard library is needed.
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

DESCRIPTION = ("Prince of Persia (1989) through SDLPoP, the open-source port of the DOS game - with its many "
               "fixes and options. Built for this machine from source; full screen and the pad out of the box.")


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    package = argv[1]
    m = re.match(r"^sdlpop-(?P<key>[a-z0-9]+)-(?P<version>.+)\.zip$", os.path.basename(package))
    if not m:
        print("not an sdlpop-<key>-<version>.zip: %s" % package)
        return 1
    key, version = m.group("key"), m.group("version")
    out = os.path.join(os.path.dirname(package), "store", key)
    os.makedirs(out, exist_ok=True)
    shutil.copy(package, out)
    shutil.copy(os.path.join(ROOT, "resources", "icon.png"), os.path.join(out, "sdlpop.png"))
    item = {
        "id": "app/sdlpop",
        "kind": "app",
        "title": "Prince of Persia (SDLPoP)",
        "version": version,
        "author": "Dávid Nagy (NagyD) and contributors; Prince of Persia by Jordan Mechner",
        "licence": "GPL-3.0-or-later (the 1989 game data: Jordan Mechner / Ubisoft, as SDLPoP ships it)",
        "description": DESCRIPTION,
        "image": "sdlpop.png",
        "files": [{"name": os.path.basename(package)}],
    }
    with open(os.path.join(out, "sdlpop.item.json"), "w", encoding="utf-8") as f:
        json.dump(item, f, indent=2)
        f.write("\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
