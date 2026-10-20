#!/usr/bin/env bash
set -Eeuo pipefail

# Logging, validation and graphical output (MODE, VNC_*) shared by the BMDE images (from the base image)
# shellcheck source=/dev/null
source /usr/local/lib/bmde/entrypoint.sh

# -------------------- Defaults (image-level) --------------------
: "${DESMUME_CLI:=0}"                 # 1 => desmume-cli, else GUI
: "${DESMUME_USE_SOUND:=1}"           # 0 => disable sound
: "${PULSE_SOCKET:=/run/pulse/native}" # host PulseAudio/PipeWire socket mount point
: "${PULSE_COOKIE_FILE:=/run/pulse/cookie}" # optional host PulseAudio cookie mount point
: "${DESMUME_GDB_STUB:=0}"            # 1 => enable GDB stub
: "${DESMUME_GDB_PORT:=1000}"
: "${AUTODISCOVER_ROM:=0}"

: "${DESMUME_CFLASH_IMAGE:=/fs/fat.img}"

: "${DESMUME_INI:=/config/desmume.ini}"   # user desmume.ini (controls, HUD...), applied on every start
: "${DESMUME_DEFAULT_INI:=${DESMUME}/share/bmde/desmume.ini}"  # default of the course, applied on first run
DESMUME_CONFIG_DIR="${HOME}/.config/desmume"

PATTERN="Did your main() return"   # substring to detect
KILL_ON_RETURN=${KILL_ON_RETURN:-1}                       # 1=enable, 0=disable
KILL_GRACE_SECS=${KILL_GRACE_SECS:-1}                     # SIGKILL after this
# DeSmuME command is expected in "$@"

# -------------------- Helpers --------------------
has_flag() {
  # $1 is the flag to search for in user args (exact match)
  local needle="$1"; shift || true
  local arr=( "$@" )
  [[ " ${arr[*]} " == *" ${needle} "* ]]
}

# -------------------- Resolve binaries --------------------
DESMUME_BIN="desmume"
[[ "${DESMUME_CLI}" == "1" ]] && DESMUME_BIN="desmume-cli"
require_bin "${DESMUME_BIN}"

# -------------------- Validate inputs --------------------
validate_int "${DESMUME_GDB_PORT}" "DESMUME_GDB_PORT"

# -------------------- Graphical output --------------------
setup_display

# -------------------- Audio (host PulseAudio / PipeWire) --------------------
setup_audio() {
  if [[ "${DESMUME_USE_SOUND}" != "1" ]]; then
    log "Sound disabled (DESMUME_USE_SOUND=${DESMUME_USE_SOUND})"
    return
  fi

  if [[ -z "${PULSE_SERVER:-}" && -S "${PULSE_SOCKET}" ]]; then
    export PULSE_SERVER="unix:${PULSE_SOCKET}"
  fi
  if [[ -z "${PULSE_COOKIE:-}" && -f "${PULSE_COOKIE_FILE}" ]]; then
    export PULSE_COOKIE="${PULSE_COOKIE_FILE}"
  fi

  if [[ -z "${PULSE_SERVER:-}" ]]; then
    log "No host audio configured; sound will not be heard."
    log "Mount the host socket (e.g. -v \$XDG_RUNTIME_DIR/pulse/native:${PULSE_SOCKET}) or set PULSE_SERVER."
    return
  fi

  if [[ "${PULSE_SERVER}" == unix:* && ! -S "${PULSE_SERVER#unix:}" ]]; then
    log "WARNING: PULSE_SERVER=${PULSE_SERVER} is not a socket; sound will not be heard."
    return
  fi
  log "Sending audio to PulseAudio server ${PULSE_SERVER}"
}
setup_audio

# -------------------- DeSmuME config (controls, HUD...) --------------------
setup_config() {
  if [[ -f "${DESMUME_INI}" ]]; then
    log "Applying DeSmuME config ${DESMUME_INI}"
    desmume-ini2gtk "${DESMUME_INI}" "${DESMUME_CONFIG_DIR}" || log "WARNING: could not apply ${DESMUME_INI}"
  elif [[ ! -f "${DESMUME_CONFIG_DIR}/config" && -f "${DESMUME_DEFAULT_INI}" ]]; then
    # First run: no key bindings saved yet, so seed them (and HUD options) from the default config
    log "Applying default DeSmuME config ${DESMUME_DEFAULT_INI}"
    desmume-ini2gtk "${DESMUME_DEFAULT_INI}" "${DESMUME_CONFIG_DIR}" || log "WARNING: could not apply default config"
  fi
}
setup_config

# -------------------- ROM selection with precedence --------------------
user_args=( "$@" )

user_rom=${ROM:=}

nds_rom=""
if [[ -n "${user_rom}" ]]; then
  nds_rom="${user_rom}"  # User will supply it via args; don't auto-append
elif [[ -n "${AUTODISCOVER_ROM}" ]]; then
  preferred_rom="/roms/rom.nds"
  search_dir="/roms"
  if [[ -f "${preferred_rom}" ]]; then
    nds_rom="${preferred_rom}"
    log "Using preferred ROM: ${preferred_rom}"
  else
    mapfile -t nds_files < <(find "${search_dir}" -maxdepth 1 -type f -name '*.nds' | sort)
    if (( ${#nds_files[@]} == 0 )); then
      die "No .nds files found in ${search_dir}. You can also pass a ROM path as a positional argument."
    fi
    nds_rom=""
    log "Not passing any ROM"
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

# 2) Add ROM if we auto-selected one (if user did not provide one, we don't add)
if [[ -n "${nds_rom}" ]]; then
  cmd+=( "${nds_rom}" )
fi

# 3) Finally append **all** user-supplied args (flags + positionals)
cmd+=( "${user_args[@]}" )

LOG_FILE=${LOG_FILE:-$HOME/logs/desmume.log}

# Make sure logs dir exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "[entrypoint] Starting emulator with log to $LOG_FILE"
echo "Emulator command: ${cmd[*]}"

# Start emulator in background, capture PID. unbuffer keeps the output line-buffered, so the watcher sees lines
# immediately
unbuffer "${cmd[@]}" 2>&1 |
tee "$LOG_FILE" &
EMU_PID=$!

if [[ "$KILL_ON_RETURN" == 0 ]]; then
  wait $EMU_PID
  exit 0
elif [[ "$KILL_ON_RETURN" == 1 ]]; then
  while kill -0 "$EMU_PID" 2>/dev/null; do
    sleep "${KILL_GRACE_SECS}"
    if grep "${PATTERN}" < "$LOG_FILE" &> /dev/null; then
      log "Reached end of main function, killing desmume"
      kill -9 "$EMU_PID"
      exit 0
    fi
  done
else
  log "Wrong option for KILL_ON_RETURN $KILL_ON_RETURN "
fi



