#!/usr/bin/env bash
# Tests the GDB stub of DeSmuME, used to debug: runs a ROM with the stub enabled and checks that it accepts connections.
# Without a display (e.g. in a container) it uses a virtual one (xvfb-run).
set -Eeuo pipefail

# Test ROM (hello-world-nds), downloaded by scripts/download_assets.sh
ROM="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/../assets/hello-world-nds.nds"
PORT=1024

work_dir="$(mktemp -d)"
cp "${ROM}" "${work_dir}/test.nds"
display=(); if [ -z "${DISPLAY:-}" ]; then display=(xvfb-run -a); fi

timeout 15 "${display[@]}" desmume --disable-sound --arm9gdb="${PORT}" "${work_dir}/test.nds" > /dev/null 2>&1 &
desmume_pid=$!
listening=1
for _ in $(seq 10); do
  if timeout 1 bash -c "</dev/tcp/localhost/${PORT}" 2>/dev/null; then
    listening=0
    break
  fi
  sleep 1
done
kill "${desmume_pid}" 2>/dev/null || true
wait "${desmume_pid}" 2>/dev/null || true
rm -rf "${work_dir}"
[ "${listening}" -eq 0 ]
echo "DeSmuME listening to port ${PORT}"
