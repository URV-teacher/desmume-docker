#!/usr/bin/env bash
# Downloads the assets of desmume-docker.
#
# Downloads the assets needed to build and test the component into assets/, the only place from where its install
# scripts (src/) and its tests (test/) take them: building never accesses external systems. For each asset: if it is
# already in assets/, checks its SHA-256; if it is not, downloads it and then checks its SHA-256. The assets that are
# always the latest version of their source have no pinned SHA-256, so they are downloaded but not checked. Fails if
# any asset could not be downloaded or does not match its SHA-256. The external resources are listed in the
# documentation of bmde (docs/development/external-resources.md).
#
#   scripts/download_assets.sh [ASSET...]    (every asset by default)
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/../assets"
SELECTED=" $* "
failed=0

# Downloads the URL $1 into the file $2
download() {
  if command -v wget > /dev/null; then
    wget -q "$1" -O "$2"
  else
    curl -fsSL "$1" -o "$2"
  fi
}

# Obtains the source $1 into the file $2: a URL, or function:NAME to make it with the function NAME (given the file)
obtain() {
  case "$1" in
    function:*) "${1#function:}" "$2" ;;
    *) download "$1" "$2" ;;
  esac
}

# SHA-256 of the file $1
checksum() {
  sha256sum "$1" | cut -d ' ' -f 1
}

# asset NAME SHA256 SOURCE...: makes sure that assets/NAME is there and has the SHA-256 SHA256 (empty if it is not
# pinned). If it is not there, it is obtained from the first SOURCE that works. An asset without SOURCE is stored in
# the repository, so it is only checked
asset() {
  local name="$1" sha256="$2" file="${ASSETS_DIR}/$1" source actual
  shift 2
  if [ "${SELECTED}" != "  " ] && [[ "${SELECTED}" != *" ${name} "* ]]; then
    return 0
  fi
  if [ -f "${file}" ]; then
    echo "${name}: present"
  else
    mkdir -p "$(dirname "${file}")"
    for source in "$@"; do
      echo "${name}: downloading from ${source}"
      if obtain "${source}" "${file}.part"; then
        mv "${file}.part" "${file}"
        break
      fi
      rm -f "${file}.part"
      echo "${name}: could not be downloaded from ${source}" >&2
    done
    if [ ! -f "${file}" ] && [ "$#" -eq 0 ]; then
      echo "${name}: ERROR, missing (it is stored in the repository: restore it with git)" >&2
      failed=1
      return 0
    elif [ ! -f "${file}" ]; then
      echo "${name}: ERROR, could not be downloaded" >&2
      failed=1
      return 0
    fi
  fi
  if [ -z "${sha256}" ]; then
    echo "${name}: not checked (latest version, without pinned SHA-256)"
    return 0
  fi
  actual="$(checksum "${file}")"
  if [ "${actual}" = "${sha256}" ]; then
    echo "${name}: OK, the SHA-256 matches"
  else
    echo "${name}: ERROR, the SHA-256 does not match (expected ${sha256}, got ${actual}). Delete it to download it" \
      "again" >&2
    failed=1
  fi
}

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
