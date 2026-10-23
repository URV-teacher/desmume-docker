#!/usr/bin/env bash
# Downloads the assets of desmume-docker into assets/.
#
# The download logic is the one shared by every component of the BMDE (download_lib.sh, copied from bmde: see it for
# the details). The external resources are listed in the documentation of bmde (docs/development/external-resources.md).
#
#   scripts/download_assets.sh [ASSET...]    (every asset by default)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=download_lib.sh
source "${SCRIPT_DIR}/download_lib.sh" "$@"

# Builds the ROM of filesystem-nds (version FILESYSTEM_NDS_COMMIT) into the file $1: a program of the course that
# reads and writes files of the FAT image with libfat, patched with the DLDI driver of the course (mpcf.dldi). It is
# built with the local devkitARM and dlditool if there are, or else with their images (DEVKITARM_IMAGE and
# DLDITOOL_IMAGE). The build is reproducible
FILESYSTEM_NDS_COMMIT=0121751d8ce58cd63fd959653b1c2f786f50d124
# shellcheck disable=SC2329  # Called through a function: source of asset
build_filesystem_nds() {
  local build_dir status=0
  build_dir="$(mktemp -d)"
  mkdir "${build_dir}/filesystem-nds"
  download "https://github.com/URV-teacher/filesystem-nds/archive/${FILESYSTEM_NDS_COMMIT}.tar.gz" \
    "${build_dir}/source.tar.gz" \
    && tar -xzf "${build_dir}/source.tar.gz" -C "${build_dir}/filesystem-nds" --strip-components=1 || status=1
  if [ "${status}" -eq 0 ] && [ -n "${DEVKITPRO:-}" ] && command -v dlditool > /dev/null; then
    make -C "${build_dir}/filesystem-nds" && (cd "${build_dir}/filesystem-nds" && dlditool mpcf.dldi filesystem-nds.nds) \
      || status=1
  elif [ "${status}" -eq 0 ]; then
    docker run --rm --user "$(id -u):$(id -g)" -v "${build_dir}/filesystem-nds:/input/filesystem-nds" \
      -w /input/filesystem-nds --entrypoint bash "${DEVKITARM_IMAGE:-aleixmt/bmde-linux:latest}" -c make \
      && docker run --rm --user "$(id -u):$(id -g)" -v "${build_dir}/filesystem-nds:/input" -w /input \
        "${DLDITOOL_IMAGE:-aleixmt/dlditool:latest}" mpcf.dldi filesystem-nds.nds || status=1
  fi
  [ "${status}" -eq 0 ] && cp "${build_dir}/filesystem-nds/filesystem-nds.nds" "$1" || status=1
  rm -rf "${build_dir}"
  return "${status}"
}

# Sources of the Ubuntu package desmume 0.9.11-3build2 (the version of the course): Launchpad keeps them permanently,
# and the Ubuntu archive is a fallback
DESMUME_SOURCES_URLS=(
  "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/desmume/0.9.11-3build2"
  "http://archive.ubuntu.com/ubuntu/pool/universe/d/desmume"
)
asset desmume_0.9.11.orig.tar.gz 3ab34ba6cc009566245025c1dd94bf449b6a1b416d24387cb42e183c78e38896 \
  "${DESMUME_SOURCES_URLS[@]/%//desmume_0.9.11.orig.tar.gz}"
asset desmume_0.9.11-3build2.diff.gz 63640982076158e7c58275805847f1e9ba7c9b1aea2e73d791ccddee9d74451a \
  "${DESMUME_SOURCES_URLS[@]/%//desmume_0.9.11-3build2.diff.gz}"
# ROM run by test_desmume.sh and test_gdbport.sh
asset hello-world-nds.nds 859c0517eb7be170f06ea54ded3fb521395aaece7b7e5fdb699311eca09f178d \
  "https://github.com/URV-teacher/hello-world-nds/releases/download/v1.0/hello-world-nds.nds"
# ROM run by test/image/test_fat.sh, which checks the files that it writes in the FAT image
asset filesystem-nds.nds ac4f806c94ec33270faa1a3eb905760f76a833a9b9a679b9811fe90311bf9ec8 function:build_filesystem_nds
# Hello world project of the course, built and run by test_operation.sh (latest version)
asset hello-world-nds.tar.gz "" "https://github.com/URV-teacher/hello-world-nds/archive/refs/heads/master.tar.gz"

exit "${failed}"
