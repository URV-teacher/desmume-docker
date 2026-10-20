#!/usr/bin/env bash
# Tests the tool that applies the configuration of the Windows DeSmuME (desmume.ini), with the default configuration
# of the course.
set -Eeuo pipefail

: "${DESMUME:?DESMUME is not set: open a new session or run . /etc/profile.d/bmde-desmume.sh}"
config_dir="$(mktemp -d)"
desmume-ini2gtk "${DESMUME}/share/bmde/desmume.ini" "${config_dir}"
grep -q "^\[KEYS\]" "${config_dir}/config"
grep -q "^Fps=true" "${config_dir}/config.cfg"
rm -rf "${config_dir}"
echo "desmume-ini2gtk OK"
