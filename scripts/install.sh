#!/bin/bash
set -eo pipefail

DEST="$HOME/.bashrc"
DESMUME="$DEVKITPRO/DeSmuME_0.9.11"
COMMAND="export DESMUME=$DESMUME"

mkdir -p "$DESMUME"

if ! grep -q "$COMMAND" "$DEST"; then
    echo "$COMMAND" >> "$DEST"
fi

sudo apt-get update && sudo apt-get install -y --no-install-recommends desmume