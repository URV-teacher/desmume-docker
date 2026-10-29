#!/usr/bin/env bash
# Tests the wrappers $DESMUME/DeSmuME.exe and $DESMUME/DeSmuME_dev.exe used by the Makefiles of the course, running a
# ROM with them as test_desmume.sh does.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
: "${DESMUME:?DESMUME is not set: open a new session or run . /etc/profile.d/bmde-desmume.sh}"
for wrapper in DeSmuME.exe DeSmuME_dev.exe; do
  DESMUME_COMMAND="${DESMUME}/${wrapper}" "${SCRIPT_DIR}/test_desmume.sh"
done
echo "DeSmuME wrappers OK"
