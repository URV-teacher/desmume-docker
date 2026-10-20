#!/usr/bin/env bash
# Tests the GDB stub of DeSmuME, used to debug: runs a ROM with the stub enabled and checks that it accepts connections.
# Without a display (e.g. in a container) it uses a virtual one (xvfb-run).
set -Eeuo pipefail

# Test ROM, from the releases of https://github.com/URV-teacher/hello-world-nds
ROM_URL="https://github.com/URV-teacher/hello-world-nds/releases/download/v1.0/hello-world-nds.nds"
ROM_SHA256="859c0517eb7be170f06ea54ded3fb521395aaece7b7e5fdb699311eca09f178d"
PORT=1024

work_dir="$(mktemp -d)"
if command -v wget > /dev/null; then
  wget -q "${ROM_URL}" -O "${work_dir}/test.nds"
else
  curl -fsSL "${ROM_URL}" -o "${work_dir}/test.nds"
fi
echo "${ROM_SHA256}  ${work_dir}/test.nds" | sha256sum -c --quiet
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
