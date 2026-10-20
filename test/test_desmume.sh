#!/usr/bin/env bash
# Tests that DeSmuME is installed, running a ROM for a few seconds. Without a display (e.g. in a container) it uses a
# virtual one (xvfb-run).
set -Eeuo pipefail

# Test ROM (hello-world-nds), downloaded by scripts/download_assets.sh
ROM="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/../assets/hello-world-nds.nds"

work_dir="$(mktemp -d)"
cp "${ROM}" "${work_dir}/test.nds"
display=(); if [ -z "${DISPLAY:-}" ]; then display=(xvfb-run -a); fi

# DeSmuME runs until it is closed, so it works if it is still running after a few seconds
status=0
timeout 5 "${display[@]}" "${DESMUME_COMMAND:-desmume}" --disable-sound "${work_dir}/test.nds" || status=$?
rm -rf "${work_dir}"
[ "${status}" -eq 124 ]
echo "DeSmuME OK"
