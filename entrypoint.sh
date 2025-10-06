#!/bin/bash

#!/usr/bin/env bash
set -euo pipefail

### ----- config via env (sane defaults) ------------------------------------
# Mode: "host" (X11 passthrough to host) or "vnc" (Xvfb + x11vnc)
MODE="${MODE:-host}"

# Host X: only used in MODE=host
HOST_DISPLAY="${DISPLAY:-:0}"

# VNC/Xvfb settings: only used in MODE=vnc
XVFB_DISPLAY="${XVFB_DISPLAY:-:99}"
GEOMETRY="${GEOMETRY:-1024x768x24}"     # WIDTHxHEIGHTxDEPTH (use depth 24/32)
VNC_PORT="${VNC_PORT:-5900}"
VNC_LISTEN="${VNC_LISTEN:-0.0.0.0}"     # where x11vnc listens
VNC_PASSWORD="${VNC_PASSWORD:-}"        # if set, create auth file; else no pw

# Which frontend: GUI vs CLI
DESMUME_CLI="${DESMUME_CLI:-0}"         # 1 -> desmume-cli, else GUI "desmume"

# Optional features
USE_SOUND="${USE_SOUND:-1}"             # 0 to disable sound
GDB_STUB="${GDB_STUB:-0}"               # 1 to enable GDB stub
GDB_PORT="${GDB_PORT:-1000}"

# Auto-add cflash image if present
CFLASH_IMAGE="${CFLASH_IMAGE:-/fs/fat.img}"

### ----- helpers ------------------------------------------------------------
log() { printf '[entrypoint] %s\n' "$*"; }

start_vnc_stack() {
  log "Starting Xvfb on ${XVFB_DISPLAY} with ${GEOMETRY}"
  Xvfb "${XVFB_DISPLAY}" -screen 0 "${GEOMETRY}" -nolisten tcp &
  XVFB_PID=$!
  export DISPLAY="${XVFB_DISPLAY}"

  # optional VNC password
  VNC_AUTH_ARG=()
  if [[ -n "${VNC_PASSWORD}" ]]; then
    mkdir -p "${HOME}/.vnc"
    x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null
    VNC_AUTH_ARG=(-rfbauth "${HOME}/.vnc/passwd")
  else
    log "WARNING: x11vnc running without password (set VNC_PASSWORD to secure)"
  fi

  log "Starting x11vnc on port ${VNC_PORT}, display ${DISPLAY}"
  x11vnc \
    -display "${DISPLAY}" \
    -listen "${VNC_LISTEN}" \
    -rfbport "${VNC_PORT}" \
    -forever -shared \
    -noshm -noxdamage \
    -o /tmp/x11vnc.log \
    "${VNC_AUTH_ARG[@]}" &
  X11VNC_PID=$!
}

cleanup() {
  set +e
  [[ -n "${X11VNC_PID:-}" ]] && kill "${X11VNC_PID}" 2>/dev/null || true
  [[ -n "${XVFB_PID:-}"   ]] && kill "${XVFB_PID}"   2>/dev/null || true
}
trap cleanup EXIT

### ----- select mode --------------------------------------------------------
case "${MODE}" in
  vnc)
    start_vnc_stack
    ;;
  host)
    export DISPLAY="${HOST_DISPLAY}"
    log "Using host X DISPLAY=${DISPLAY} (no VNC in this mode)"
    ;;
  *)
    echo "Invalid MODE='${MODE}'. Use MODE=host or MODE=vnc" >&2
    exit 2
    ;;
esac


nds_rom=""

preferred_rom="/roms/__JPprofes.nds"
search_dir="/roms"
if [ -f "${preferred_rom}" ]; then
    # If preferred ROM exists, use it
    nds_rom="${preferred_rom}"
    echo "Using preferred ROM: ${preferred_rom}"
else
  # Otherwise, search for first .nds file in directory
  nds_files=($(find "${search_dir}" -maxdepth 1 -type f -name '*.nds'))

  # Check if any .nds files were found
  if [ ${#nds_files[@]} -eq 0 ]; then
      echo "Error: No .nds files found in ${search_dir}. Aborting execution."
      exit 1
  fi

  # Use the first .nds file found
  first_nds="${nds_files[0]}"
  echo "Using fallback ROM: ${first_nds}"
  nds_rom="${first_nds}"
fi


### ----- build desmume command ---------------------------------------------
DESMUME_BIN="desmume"
[[ "${DESMUME_CLI}" == "1" ]] && DESMUME_BIN="desmume-cli"

cmd=( "${DESMUME_BIN}" )

# Append rom
cmd+=( "${nds_rom}" )

# Append target ROM (first arg) and pass-through args
if [[ $# -gt 0 ]]; then
  cmd+=( "$@" )
fi

# Add cflash image if present and not already specified
if [[ -f "${CFLASH_IMAGE}" ]] && [[ " ${cmd[*]} " != *" --cflash-image "* ]]; then
  cmd+=( --cflash-image "${CFLASH_IMAGE}" )
fi

# Sound handling
if [[ "${USE_SOUND}" != "1" ]]; then
  export SDL_AUDIODRIVER=dummy
  cmd+=( --disable-sound )
fi

# GDB stub
if [[ "${GDB_STUB}" == "1" ]]; then
  # Flags vary by build; common ones shown:
  cmd+=( --gdb-stub --arm9gdb-port "${GDB_PORT}" )
fi

log "Running: ${cmd[*]}"
exec "${cmd[@]}"

