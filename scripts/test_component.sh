#!/bin/bash
set -eo pipefail

cd "$DEVKITPRO/examples/nds/audio/maxmod/basic_sound"
# candyNDS_full is already built, but if not you can build it with make, testing also the build operation
desmume basic_sound.nds
