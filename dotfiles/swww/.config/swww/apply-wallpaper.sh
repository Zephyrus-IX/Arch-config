#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# APPLY WALLPAPER (Control Center compatible)
#
# Usage:
#   apply-wallpaper.sh "/full/path/to/image.png" [preset]
#
# - Control Center calls this with only the first arg (image path).
# - Preset can be selected by:
#     1) second arg
#     2) SWWW_PRESET env var
#     3) default preset name below
###############################################################################

###############################################################################
# CONFIG / PATHS (single place to edit later)
###############################################################################
SYS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/system-theme"
STATE_DIR="$SYS_DIR/state"

CURRENT_THEME_FILE="$STATE_DIR/current-theme"
CURRENT_WALLPAPER_LINK="$STATE_DIR/current-wallpaper"
CURRENT_WALLPAPER_TXT="$STATE_DIR/current-wallpaper.txt"

# Where transition preset helpers live (relative to this script)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PRESETS_DIR="$SCRIPT_DIR/transitions"

# Default preset if none specified
DEFAULT_PRESET="default"

###############################################################################
# HELPERS (small + readable)
###############################################################################
die() {
  echo "apply-wallpaper: $*" >&2; exit 1;
}

is_supported_image() {
  local path="${1:-}"
  case "${path,,}" in
    *.png|*.jpg|*.jpeg|*.webp) return 0 ;;
    *) return 1 ;;
  esac
}

read_current_theme() {
  [[ -f "$CURRENT_THEME_FILE" ]] || return 1
  local t
  t="$(<"$CURRENT_THEME_FILE")"
  t="${t//$'\r'/}"
  t="$(printf '%s' "$t" | xargs)"
  [[ -n "$t" ]] || return 1
  printf '%s' "$t"
}

load_preset() {
  local preset="${1:?preset required}"
  local preset_file="$PRESETS_DIR/${preset}.sh"

  [[ -d "$PRESETS_DIR" ]] || die "presets dir not found: $PRESETS_DIR"
  [[ -f "$preset_file" ]] || die "preset not found: $preset_file"

  # Default args (preset may override/append)
  SWWW_ARGS=()

  # shellcheck source=/dev/null
  source "$preset_file"

  # Preset must set SWWW_ARGS as a bash array (can be empty)
  declare -p SWWW_ARGS >/dev/null 2>&1 || die "preset '$preset' did not define SWWW_ARGS array"
}

apply_with_swww() {
  local img="${1:?image path required}"
  command -v swww >/dev/null 2>&1 || die "swww is not installed (needed to apply wallpapers)."

  # SWWW_ARGS comes from preset
  swww img "$img" "${SWWW_ARGS[@]}"
}

persist_wallpaper_state() {
  local img="${1:?image path required}"
  mkdir -p "$STATE_DIR"
  ln -sfn "$img" "$CURRENT_WALLPAPER_LINK"
  printf '%s\n' "$img" > "$CURRENT_WALLPAPER_TXT"
}

###############################################################################
# MAIN
###############################################################################
main() {
  local selected_path="${1:-}"
  local preset="${2:-${SWWW_PRESET:-$DEFAULT_PRESET}}"

  [[ -n "$selected_path" ]] || die "missing argument. Expected a full path to an image."
  [[ -f "$selected_path" ]] || {
    local theme=""
    theme="$(read_current_theme || true)"
    if [[ -n "$theme" ]]; then
      die "file not found: $selected_path (current theme: $theme)"
    else
      die "file not found: $selected_path"
    fi
  }

  is_supported_image "$selected_path" || die "unsupported file type: $selected_path"

  load_preset "$preset"
  apply_with_swww "$selected_path"
  persist_wallpaper_state "$selected_path"
}

main "$@"