#!/usr/bin/env bash
# Tests the run operation: builds the hello world project of the course and runs it with its Makefile (make run), as
# in the Windows BMDE. Needs devkitARM, libnds and git. Without a display (e.g. in a container) it uses a virtual one.
set -Eeuo pipefail

work_dir="$(mktemp -d)"
git clone https://github.com/URV-teacher/hello-world-nds.git "${work_dir}/hello-world-nds"
make -C "${work_dir}/hello-world-nds"
display=(); if [ -z "${DISPLAY:-}" ]; then display=(xvfb-run -a); fi

# make run starts DeSmuME in the background: it works if it is still running after a few seconds
"${display[@]}" bash -c "make -C '${work_dir}/hello-world-nds' run && sleep 5 && pgrep -x desmume && pkill -x desmume"
rm -rf "${work_dir}"
echo "make run OK"
