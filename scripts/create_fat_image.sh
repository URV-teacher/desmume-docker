#!/usr/bin/env bash
# Creates an empty FAT image (fs/fat.img by default) to use as the CompactFlash card of DeSmuME (--cflash-image, or
# DESMUME_CFLASH_IMAGE of the entrypoint), so the programs of the course can read and write files with libfat. It has
# the format of the image of the course: FAT16 of 128 MB, with 512-byte sectors, 4 sectors per cluster and 512 entries
# in the root directory. Does not replace an existing image, since it may have files of the programs. Needs mkfs.fat
# (package dosfstools), but not root.
#
#   scripts/create_fat_image.sh [IMAGE]
set -Eeuo pipefail

IMAGE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)/fs/fat.img}"

if [ -e "${IMAGE}" ]; then
  echo "${IMAGE} already exists: delete it to create an empty one" >&2
  exit 1
fi
mkdir -p "$(dirname "${IMAGE}")"
# Size in KiB
mkfs.fat -C -F 16 -S 512 -s 4 -R 4 -r 512 -g 64/32 "${IMAGE}" 131072
echo "Created ${IMAGE}"
