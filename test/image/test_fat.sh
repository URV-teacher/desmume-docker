#!/usr/bin/env bash
# Tests the FAT image of the image, used as the CompactFlash card of DeSmuME by the programs that read and write files
# with libfat: runs the ROM of filesystem-nds with an empty FAT image, and checks the files that it writes into it.
# Runs the image from the host (unlike the tests of test/, which run inside the image), so it needs Docker, mkfs.fat
# (package dosfstools) and mtools.
#
#   test/image/test_fat.sh [IMAGE]    (aleixmt/desmume:latest by default)
set -Eeuo pipefail

IMAGE="${1:-aleixmt/desmume:latest}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)"
# ROM of filesystem-nds, built by scripts/download_assets.sh
ROM="${REPO_DIR}/assets/filesystem-nds.nds"

work_dir="$(mktemp -d)"
mkdir "${work_dir}/roms" "${work_dir}/fs"
cp "${ROM}" "${work_dir}/roms/"
"${REPO_DIR}/scripts/create_fat_image.sh" "${work_dir}/fs/fat.img" > /dev/null
# The emulator runs as the user of the image, which has to write into the FAT image
chmod -R a+rwX "${work_dir}/fs"

# The entrypoint stops the emulator when main returns, so the container ends by itself once the ROM is done
timeout 120 docker run --rm -v "${work_dir}/roms:/roms:ro" -v "${work_dir}/fs:/fs" \
  -e MODE=none -e DESMUME_CLI=1 -e DESMUME_USE_SOUND=0 "${IMAGE}" /roms/filesystem-nds.nds || true

status=0
expected="$(printf 'Hola, este es un test en DeSmuME.\nProbando escritura en archivo.')"
if [ "$(mtype -i "${work_dir}/fs/fat.img" ::output.txt 2> /dev/null)" != "${expected}" ]; then
  echo "output.txt was not written in the FAT image" >&2
  status=1
fi
if [ "$(mtype -i "${work_dir}/fs/fat.img" ::EXIT_CODE 2> /dev/null)" != "0" ]; then
  echo "EXIT_CODE was not written in the FAT image" >&2
  status=1
fi
rm -rf "${work_dir}"
[ "${status}" -eq 0 ]
echo "FAT image OK"
