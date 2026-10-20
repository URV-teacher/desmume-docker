#!/usr/bin/env bash
# Installs DeSmuME 0.9.11 (the version of the course) into /URV/bmde/DeSmuME_0.9.11, and its environment (DESMUME,
# PATH) into /etc/profile.d/bmde-desmume.sh. Standalone: can be run in an Ubuntu / Debian host, and is also used by the
# BMDE Docker images. Set BMDE_ROOT to install into another directory.
#
# DeSmuME is built from the sources of the Debian / Ubuntu package (downloaded from Launchpad), with HUD and GDB stub
# support, which the distribution packages lack or do not provide for this version anymore. Also installs the tool to
# apply the configuration of the Windows DeSmuME (desmume-ini2gtk) and the default configuration of the course.
set -Eeuo pipefail

BMDE_ROOT="${BMDE_ROOT:-/URV/bmde}"
SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_URL="https://raw.githubusercontent.com/URV-teacher/desmume-docker/master"
DESMUME_DIR="${BMDE_ROOT}/DeSmuME_0.9.11"
# Packages needed to run DeSmuME, computed when building it
RUNTIME_PACKAGES="${DESMUME_DIR}/share/bmde/runtime-packages"

# Sources of the Ubuntu package desmume 0.9.11-3build2. Launchpad keeps them permanently; the Ubuntu archive is a
# fallback. The checksums pin the exact files, whatever the mirror
DESMUME_SOURCES_URLS=(
  "https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/desmume/0.9.11-3build2"
  "http://archive.ubuntu.com/ubuntu/pool/universe/d/desmume"
)
DESMUME_ORIG_SHA256="3ab34ba6cc009566245025c1dd94bf449b6a1b416d24387cb42e183c78e38896"
DESMUME_DIFF_SHA256="63640982076158e7c58275805847f1e9ba7c9b1aea2e73d791ccddee9d74451a"

# Downloads the source file $1 of DeSmuME to $3, checking that its SHA-256 is $2
download_source() {
  local url
  for url in "${DESMUME_SOURCES_URLS[@]}"; do
    if wget -q "${url}/$1" -O "$3" && echo "$2  $3" | sha256sum -c --quiet; then
      return 0
    fi
    echo "Could not download $1 from ${url}" >&2
  done
  return 1
}

# Copies a file of the repository to $2, downloading it if the script is not run from the repository
fetch() {
  if [ -f "${SCRIPT_DIR}/../$1" ]; then
    cp "${SCRIPT_DIR}/../$1" "$2"
  else
    wget -q "${REPO_URL}/$1" -O "$2"
  fi
}

build_desmume() {
  ${SUDO} apt-get update
  ${SUDO} apt-get install -y --no-install-recommends \
    ca-certificates wget build-essential autoconf automake intltool pkg-config patch \
    libgtk2.0-dev libsdl1.2-dev libagg-dev libsoundtouch-dev libopenal-dev libosmesa6-dev libglu1-mesa-dev \
    libtinyxml-dev libpcap-dev zlib1g-dev

  local build_dir
  build_dir="$(mktemp -d)"
  download_source desmume_0.9.11.orig.tar.gz "${DESMUME_ORIG_SHA256}" "${build_dir}/desmume.orig.tar.gz"
  download_source desmume_0.9.11-3build2.diff.gz "${DESMUME_DIFF_SHA256}" "${build_dir}/desmume.diff.gz"
  tar -xzf "${build_dir}/desmume.orig.tar.gz" -C "${build_dir}"
  (
    cd "${build_dir}/desmume-0.9.11"
    # Patches of the Debian package (build fixes for newer compilers)
    zcat ../desmume.diff.gz | patch -p1 -s
    while read -r p; do
      patch -p1 -s < "debian/patches/${p}"
    done < debian/patches/series
    # libagg >= 2.6 dropped comp_op_minus / comp_op_contrast, which the HUD code of DeSmuME never uses
    sed -i '/agg::comp_op_minus\|agg::comp_op_contrast/d' src/agg2d.h
    autoreconf -fi
    ./configure --prefix="${DESMUME_DIR}" --enable-hud --enable-gdb-stub --enable-osmesa
    make -j"$(nproc)"
    ${SUDO} make install
  )
  rm -rf "${build_dir}"

  # Packages of the shared libraries that DeSmuME uses, to install them without the build dependencies
  ${SUDO} mkdir -p "$(dirname "${RUNTIME_PACKAGES}")"
  ldd "${DESMUME_DIR}/bin/desmume" "${DESMUME_DIR}/bin/desmume-cli" \
    | awk '/=> \// { print $3 }' | sort -u | xargs -r realpath \
    | xargs -r dpkg -S 2>/dev/null | cut -d: -f1 | sort -u \
    | ${SUDO} tee "${RUNTIME_PACKAGES}" > /dev/null
}

if [ ! -x "${DESMUME_DIR}/bin/desmume" ]; then
  build_desmume
fi

# Runtime dependencies (python3 for desmume-ini2gtk)
${SUDO} apt-get update
# shellcheck disable=SC2046
${SUDO} apt-get install -y --no-install-recommends python3 $(cat "${RUNTIME_PACKAGES}")

# Configuration tool and default configuration (controls, HUD) of the course
${SUDO} mkdir -p "${DESMUME_DIR}/share/bmde"
fetch scripts/desmume-ini2gtk.py /tmp/desmume-ini2gtk
${SUDO} install -m 755 /tmp/desmume-ini2gtk "${DESMUME_DIR}/bin/desmume-ini2gtk"
fetch config/desmume.ini /tmp/desmume.ini
${SUDO} install -m 644 /tmp/desmume.ini "${DESMUME_DIR}/share/bmde/desmume.ini"
rm -f /tmp/desmume-ini2gtk /tmp/desmume.ini

${SUDO} tee /etc/profile.d/bmde-desmume.sh > /dev/null <<PROFILE
export DESMUME="${DESMUME_DIR}"
case ":\${PATH}:" in
  *":${DESMUME_DIR}/bin:"*) ;;
  *) export PATH="${DESMUME_DIR}/bin:\${PATH}" ;;
esac
PROFILE

echo "DeSmuME installed in ${DESMUME_DIR}. Open a new session or run: . /etc/profile.d/bmde-desmume.sh"
echo "To use the controls of the course: desmume-ini2gtk ${DESMUME_DIR}/share/bmde/desmume.ini"
