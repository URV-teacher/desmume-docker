#!/bin/bash
set -eo pipefail

cd "$DEVKITPRO/examples/nds/audio/maxmod/basic_sound"
desmume --arm9gdb=1024 basic_sound.nds &>/dev/null &  # --arm9gdb-port instead of --arm9gdb= In newer versions
DESMUME_PID=$!
sleep 2
if netstat -tlp 2>/dev/null | grep -q 1024; then
  echo "DeSmuME listening to port"
else
  echo "DeSmuME not listening to port"
fi
kill -9 $DESMUME_PID