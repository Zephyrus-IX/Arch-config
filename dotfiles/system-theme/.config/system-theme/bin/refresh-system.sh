#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# refresh-ui.sh
#
# Purpose:
#   Refresh/reload UI components after a theme is applied.
#
# Usage:
#   refresh-ui.sh            # prefer reload signals; restart only if missing
#   refresh-ui.sh --hard     # force restarts (more reliable, slightly heavier)
#
# Notes:
#   - This script should NEVER cause theme application to fail.
#   - It will attempt "reload" first where possible, and fall back to restart.
###############################################################################

###############################################################################
# PATHS / DEFAULTS (edit here)
###############################################################################
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Your launch wrappers (matches your apply-theme.sh style)
WAYBAR_LAUNCH="$CONFIG_DIR/waybar/bin/launch.sh"
SWAYNC_LAUNCH="$CONFIG_DIR/swaync/bin/launch.sh"

# Process names (used for pkill/pgrep)
WAYBAR_PROC="waybar"
SWAYNC_PROC="swaync"
WLOGOUT_PROC="wlogout"

# Behaviour toggles (0/1). You can disable parts without deleting code.
DO_HYPR_RELOAD=1
DO_WAYBAR=1
DO_SWAYNC=1
DO_WLOGOUT_CLOSE=1

# Waybar reload signals (depends on build; we try both)
WAYBAR_RELOAD_SIG_PRIMARY="USR2"
WAYBAR_RELOAD_SIG_FALLBACK="USR1"

# Small delays for cleaner restarts
RESTART_DELAY_SEC="0.15"

###############################################################################
# UTILITIES
###############################################################################
log() { printf 'refresh-ui: %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

pkill_safe() {
  # usage: pkill_safe SIG PROCNAME
  local sig="${1:?sig required}"
  local name="${2:?proc name required}"
  pkill "-$sig" -x "$name" >/dev/null 2>&1 || true
}

pgrep_any() {
  # usage: pgrep_any PROCNAME
  local name="${1:?proc name required}"
  pgrep -x "$name" >/dev/null 2>&1
}

run_safe() {
  # Never fail the caller.
  "$@" >/dev/null 2>&1 || true
}

###############################################################################
# REFRESH ACTIONS
###############################################################################
refresh_hyprland() {
  (( DO_HYPR_RELOAD == 1 )) || return 0
  have hyprctl || return 0

  log "Hyprland: hyprctl reload"
  run_safe hyprctl reload
}

refresh_waybar() {
  (( DO_WAYBAR == 1 )) || return 0
  have waybar || { log "Waybar: not installed; skipping"; return 0; }

  if (( HARD == 0 )); then
    log "Waybar: reload (SIG${WAYBAR_RELOAD_SIG_PRIMARY}, then SIG${WAYBAR_RELOAD_SIG_FALLBACK})"
    pkill_safe "$WAYBAR_RELOAD_SIG_PRIMARY" "$WAYBAR_PROC"
    pkill_safe "$WAYBAR_RELOAD_SIG_FALLBACK" "$WAYBAR_PROC"

    # If it's not running (or reload didn't wake it), start via launch script if present.
    if ! pgrep_any "$WAYBAR_PROC"; then
      if [[ -x "$WAYBAR_LAUNCH" ]]; then
        log "Waybar: not running; starting via $WAYBAR_LAUNCH"
        run_safe "$WAYBAR_LAUNCH"
      else
        log "Waybar: not running; starting via waybar"
        run_safe waybar
      fi
    fi
  else
    log "Waybar: restart"
    pkill_safe TERM "$WAYBAR_PROC"
    sleep "$RESTART_DELAY_SEC"

    if [[ -x "$WAYBAR_LAUNCH" ]]; then
      run_safe "$WAYBAR_LAUNCH"
    else
      run_safe waybar
    fi
  fi
}

refresh_swaync() {
  (( DO_SWAYNC == 1 )) || return 0
  have swaync || { log "SwayNC: not installed; skipping"; return 0; }

  if (( HARD == 0 )); then
    # Version differences: some builds support -R / -rs; we try and ignore failures.
    if have swaync-client; then
      log "SwayNC: trying swaync-client reload"
      run_safe swaync-client -R
      run_safe swaync-client -rs
      run_safe swaync-client -D
    else
      log "SwayNC: swaync-client missing; using light touch (no-op if not running)"
    fi

    # Ensure it's running (start via launch script if present)
    if ! pgrep_any "$SWAYNC_PROC"; then
      if [[ -x "$SWAYNC_LAUNCH" ]]; then
        log "SwayNC: not running; starting via $SWAYNC_LAUNCH"
        run_safe "$SWAYNC_LAUNCH"
      else
        log "SwayNC: not running; starting via swaync"
        run_safe swaync
      fi
    fi
  else
    log "SwayNC: restart"
    pkill_safe TERM "$SWAYNC_PROC"
    sleep "$RESTART_DELAY_SEC"

    if [[ -x "$SWAYNC_LAUNCH" ]]; then
      run_safe "$SWAYNC_LAUNCH"
    else
      run_safe swaync
    fi
  fi
}

close_wlogout() {
  (( DO_WLOGOUT_CLOSE == 1 )) || return 0
  log "wlogout: close if open"
  pkill_safe TERM "$WLOGOUT_PROC"
}

###############################################################################
# MAIN
###############################################################################
HARD=0
if [[ "${1:-}" == "--hard" ]]; then
  HARD=1
fi

log "starting (hard=$HARD)"

refresh_hyprland
refresh_waybar
refresh_swaync
close_wlogout

log "done"
exit 0