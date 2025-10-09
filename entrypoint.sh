#!/usr/bin/env bash
set -Eeuo pipefail

# -------------------- Defaults (image-level) --------------------
: "${MODE:=none}"                     # 'host' | 'vnc' | 'none'
: "${DISPLAY:=:0}"                    # host X (used in host mode)
export X11_DISPLAY="${DISPLAY}"

: "${VNC_XVFB_DISPLAY:=:99}"          # used only in vnc mode
export XVFB_DISPLAY="${VNC_XVFB_DISPLAY}"

: "${VNC_GEOMETRY:=1024x768x24}"      # WIDTHxHEIGHTxDEPTH (24 or 32)
export GEOMETRY="${VNC_GEOMETRY}"

: "${VNC_PORT:=5900}"
: "${VNC_LISTEN:=0.0.0.0}"
: "${VNC_PASSWORD:=}"                 # optional; empty => no auth

: "${DESMUME_CLI:=0}"                 # 1 => desmume-cli, else GUI
: "${DESMUME_USE_SOUND:=1}"           # 0 => disable sound
: "${DESMUME_GDB_STUB:=0}"            # 1 => enable GDB stub
: "${DESMUME_GDB_PORT:=1000}"

: "${DESMUME_CFLASH_IMAGE:=/fs/fat.img}"

# -------------------- Helpers --------------------
log() { printf '[entrypoint] %s\n' "$*"; }
die() { printf '[entrypoint][ERROR] %s\n' "$*" >&2; exit 2; }

has_flag() {
  # $1 is the flag to search for in user args (exact match)
  local needle="$1"; shift || true
  local arr=( "$@" )
  [[ " ${arr[*]} " == *" ${needle} "* ]]
}

first_positional_nds() {
  # returns first non-flag arg ending with .nds, or empty
  local a
  for a in "$@"; do
    [[ "$a" == --* ]] && continue
    [[ "$a" == -*  ]] && continue
    [[ "$a" == *.nds ]] && { printf '%s' "$a"; return 0; }
  done
  return 1
}

require_bin() { command -v "$1" >/dev/null 2>&1 || die "Missing required binary: $1"; }

validate_int() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "Expected integer, got '$1' for $2"
}

cleanup() {
  set +e
  [[ -n "${X11VNC_PID:-}" ]] && kill "${X11VNC_PID}" 2>/dev/null || true
  [[ -n "${XVFB_PID:-}"   ]] && kill "${XVFB_PID}"   2>/dev/null || true
}
trap cleanup EXIT

# -------------------- Resolve binaries --------------------
DESMUME_BIN="desmume"
[[ "${DESMUME_CLI}" == "1" ]] && DESMUME_BIN="desmume-cli"
require_bin "${DESMUME_BIN}"

# -------------------- Validate inputs --------------------
case "${MODE}" in
  vnc|host|none) ;;
  *) die "Invalid MODE='${MODE}'. Use MODE=host, MODE=vnc or MODE=none." ;;
esac

# Only validate ports if relevant
if [[ "${MODE}" == "vnc" ]]; then
  validate_int "${VNC_PORT}" "VNC_PORT"
fi
validate_int "${DESMUME_GDB_PORT}" "DESMUME_GDB_PORT"

# -------------------- Prepare X / VNC stack --------------------
start_vnc_stack() {
  require_bin Xvfb
  require_bin x11vnc

  log "Starting Xvfb on ${XVFB_DISPLAY} with geometry ${GEOMETRY}"
  Xvfb "${XVFB_DISPLAY}" -screen 0 "${GEOMETRY}" -nolisten tcp &
  XVFB_PID=$!
  export DISPLAY="${XVFB_DISPLAY}"

  local VNC_AUTH_ARG=()
  if [[ -n "${VNC_PASSWORD}" ]]; then
    mkdir -p "${HOME}/.vnc"
    x11vnc -storepasswd "${VNC_PASSWORD}" "${HOME}/.vnc/passwd" >/dev/null
    VNC_AUTH_ARG=(-rfbauth "${HOME}/.vnc/passwd")
  else
    log "WARNING: x11vnc running without password (set VNC_PASSWORD to secure)"
  fi

  log "Starting x11vnc on ${VNC_LISTEN}:${VNC_PORT} (DISPLAY=${DISPLAY})"
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

mkdir ~/.vnc && \
touch ~/.vnc/passwd && \
x11vnc -storepasswd "${VNC_PASSWORD}" ~/.vnc/passwd



case "${MODE}" in
  vnc)
    start_vnc_stack
    ;;
  host)
    export DISPLAY="${X11_DISPLAY}"
    log "Using host X DISPLAY=${DISPLAY} (no VNC in this mode)"
    ;;
  none)
    # Do not touch DISPLAY or start any X/VNC services.
    log "MODE=none: no X/VNC will be started; running DeSmuME as-is."
    ;;
esac

# -------------------- ROM selection with precedence --------------------
user_args=( "$@" )

# If user already passed a ROM (.nds positional), **do not** auto-pick
user_rom="$(first_positional_nds "${user_args[@]}")" || true

nds_rom=""
if [[ -n "${user_rom}" ]]; then
  nds_rom=""  # User will supply it via args; don't auto-append
else
  preferred_rom="/roms/__JPprofes.nds"
  search_dir="/roms"
  if [[ -f "${preferred_rom}" ]]; then
    nds_rom="${preferred_rom}"
    log "Using preferred ROM: ${preferred_rom}"
  else
    mapfile -t nds_files < <(find "${search_dir}" -maxdepth 1 -type f -name '*.nds' | sort)
    if (( ${#nds_files[@]} == 0 )); then
      die "No .nds files found in ${search_dir}. You can also pass a ROM path as a positional argument."
    fi
    nds_rom="${nds_files[0]}"
    log "Using fallback ROM: ${nds_rom}"
  fi
fi

# -------------------- Build command with precedence --------------------
cmd=( "${DESMUME_BIN}" )

# 1) Add env-derived flags **only if** user did not already pass them

# CFlash
if [[ -f "${DESMUME_CFLASH_IMAGE}" ]] && ! has_flag "--cflash-image" "${user_args[@]}"; then
  cmd+=( --cflash-image "${DESMUME_CFLASH_IMAGE}" )
fi

# Sound
if [[ "${DESMUME_USE_SOUND}" != "1" ]]; then
  export SDL_AUDIODRIVER=dummy
  if ! has_flag "--disable-sound" "${user_args[@]}"; then
    cmd+=( --disable-sound )
  fi
fi

# GDB stub
if [[ "${DESMUME_GDB_STUB}" == "1" ]]; then
  ! has_flag "--gdb-stub"          "${user_args[@]}" && cmd+=( --gdb-stub )
  if ! has_flag "--arm9gdb-port"   "${user_args[@]}"; then
    cmd+=( --arm9gdb-port "${DESMUME_GDB_PORT}" )
  fi
fi

# 2) Add ROM if we auto-selected one (if user provided one, we don't add)
if [[ -n "${nds_rom}" ]]; then
  cmd+=( "${nds_rom}" )
fi

# 3) Finally append **all** user-supplied args (flags + positionals)
cmd+=( "${user_args[@]}" )


# --- config ---------------------------------------------------------------
WATCH_PATTERN=${WATCH_PATTERN:-"did your main return?"}   # substring to detect
KILL_ON_RETURN=${KILL_ON_RETURN:-1}                       # 1=enable, 0=disable
KILL_GRACE_SECS=${KILL_GRACE_SECS:-2}                     # SIGKILL after this
# DeSmuME command is expected in "$@"
# -------------------------------------------------------------------------

if [[ "${KILL_ON_RETURN}" != "1" ]]; then
  echo "[entrypoint] KILL_ON_RETURN=0 → exec directly"
  exec "${cmd[*]}"
fi

echo "[entrypoint] Starting emulator with watchdog for: ${WATCH_PATTERN}"

# Ensure line-buffered stdout/stderr so the watcher sees lines immediately
# (stdbuf is in coreutils; busybox-alpine has 'stdbuf' in 'coreutils' pkg)
EMULATOR_CMD=(stdbuf -oL -eL ${cmd[*]})
LOG_FILE=${LOG_FILE:-/logs/desmume.log}

# Make sure logs dir exists
mkdir -p "$(dirname "$LOG_FILE")"

echo "[entrypoint] Starting emulator with log to $LOG_FILE"

# Start emulator in background, capture PID
"${EMULATOR_CMD[@]}" 2>&1 \
| tee -a "$LOG_FILE" \
| awk -v pat="$WATCH_PATTERN" -v OFS="" '
    { print }  # echo every line back to console
    index($0, pat) {
      printf("[watchdog] Detected pattern: \"%s\" → requesting shutdown...\n", pat) > "/dev/stderr";
      system("kill -TERM " ENVIRON["EMU_PID"]);
    }
  ' &
EMU_PID=$!

# Wait for emulator to exit; capture code
wait "${EMU_PID}" || EMU_RC=$? || true
EMU_RC=${EMU_RC:-0}

# If we initiated the kill, give it a moment, then SIGKILL if needed
if kill -0 "${EMU_PID}" 2>/dev/null; then
  :
else
  # already gone
  :
fi

# If still alive (TERM didn’t work), force kill after grace period
if kill -0 "${EMU_PID}" 2>/dev/null; then
  sleep "${KILL_GRACE_SECS}"
  if kill -0 "${EMU_PID}" 2>/dev/null; then
    echo "[watchdog] Forcing SIGKILL to PID ${EMU_PID}"
    kill -KILL "${EMU_PID}" 2>/dev/null || true
    wait "${EMU_PID}" || true
  fi
fi

exit "${EMU_RC}"
