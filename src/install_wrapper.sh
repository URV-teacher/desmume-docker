#!/usr/bin/env bash
# Installs the wrappers $DESMUME/DeSmuME.exe and $DESMUME/DeSmuME_dev.exe, which the Makefiles of the course use to run
# (make run) and debug (make debug) the projects as in the Windows BMDE. Needs DeSmuME (install_desmume.sh).
# Standalone: can be run in an Ubuntu / Debian host, and is also used by the BMDE Docker images.
set -Eeuo pipefail

BMDE_ROOT="${BMDE_ROOT:-/URV/bmde}"
SUDO=""; if [ "$(id -u)" -ne 0 ]; then SUDO=sudo; fi
DESMUME_DIR="${BMDE_ROOT}/DeSmuME_0.9.11"

for wrapper in DeSmuME.exe DeSmuME_dev.exe; do
  ${SUDO} tee "${DESMUME_DIR}/${wrapper}" > /dev/null <<WRAPPER
#!/usr/bin/env sh
exec "${DESMUME_DIR}/bin/desmume" "\$@"
WRAPPER
  ${SUDO} chmod +x "${DESMUME_DIR}/${wrapper}"
done

echo "Wrappers installed in ${DESMUME_DIR}"
