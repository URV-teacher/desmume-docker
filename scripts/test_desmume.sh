#!/usr/bin/env bash
# Tests that DeSmuME is installed, running a ROM for a few seconds. Without a display (e.g. in a container) it uses a
# virtual one (xvfb-run).
set -Eeuo pipefail

# Test ROM, from the releases of https://github.com/URV-teacher/hello-world-nds
ROM_URL="https://github.com/URV-teacher/hello-world-nds/releases/download/v1.0/hello-world-nds.nds"
ROM_SHA256="859c0517eb7be170f06ea54ded3fb521395aaece7b7e5fdb699311eca09f178d"

work_dir="$(mktemp -d)"
if command -v wget > /dev/null; then
  wget -q "${ROM_URL}" -O "${work_dir}/test.nds"
else
  curl -fsSL "${ROM_URL}" -o "${work_dir}/test.nds"
fi
echo "${ROM_SHA256}  ${work_dir}/test.nds" | sha256sum -c --quiet
display=(); if [ -z "${DISPLAY:-}" ]; then display=(xvfb-run -a); fi

# DeSmuME runs until it is closed, so it works if it is still running after a few seconds
status=0
timeout 5 "${display[@]}" "${DESMUME_COMMAND:-desmume}" --disable-sound "${work_dir}/test.nds" || status=$?
rm -rf "${work_dir}"
[ "${status}" -eq 124 ]
echo "DeSmuME OK"
