#!/usr/bin/env bash
# Tests the run operation: builds the hello world project of the course and runs it with its Makefile (make run), as
# in the Windows BMDE. Needs devkitARM and libnds. Without a display (e.g. in a container) it uses a virtual one.
set -Eeuo pipefail

work_dir="$(mktemp -d)"
# Hello world project of the course, downloaded by scripts/download_assets.sh
mkdir "${work_dir}/hello-world-nds"
tar -xzf "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/../assets/hello-world-nds.tar.gz" \
  -C "${work_dir}/hello-world-nds" --strip-components=1
make -C "${work_dir}/hello-world-nds"
display=(); if [ -z "${DISPLAY:-}" ]; then display=(xvfb-run -a); fi

# make run starts DeSmuME in the background: it works if it is still running after a few seconds
"${display[@]}" bash -c "make -C '${work_dir}/hello-world-nds' run && sleep 5 && pgrep -x desmume && pkill -x desmume"
rm -rf "${work_dir}"
echo "make run OK"
