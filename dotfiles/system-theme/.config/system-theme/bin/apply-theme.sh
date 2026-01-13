#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# apply-theme.sh
#
# Usage:
#   apply-theme.sh "<theme-name>"   # control center calls this form
#   apply-theme.sh                  # optional: interactive rofi picker
#
# Theme layout:
#   ~/.config/system-theme/themes/<theme>/palette.json
#   ~/.config/system-theme/themes/<theme>/wallpapers/ (optional)
#
# State files:
#   ~/.config/system-theme/state/current-theme
#   ~/.config/system-theme/state/current-wallpaper.txt
#   ~/.config/system-theme/state/current-wallpaper (symlink)
#
# Auto theme:
#   ~/.config/system-theme/auto/palette.json (generated)
#   ~/.config/system-theme/auto/wallpaper.current (path to image)
###############################################################################

###############################################################################
# PATHS / DEFAULTS (edit here)
###############################################################################
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

SYS_DIR="$CONFIG_DIR/system-theme"
THEMES_DIR="$SYS_DIR/themes"
STATE_DIR="$SYS_DIR/state"
AUTO_DIR="$SYS_DIR/auto"

CURRENT_THEME_FILE="$STATE_DIR/current-theme"
CURRENT_WALLPAPER_TXT="$STATE_DIR/current-wallpaper.txt"
CURRENT_WALLPAPER_LINK="$STATE_DIR/current-wallpaper"

AUTO_WALLPAPER_FILE="$AUTO_DIR/wallpaper.current"
AUTO_PALETTE_JSON="$AUTO_DIR/palette.json"

RENDER_SCRIPT="$SYS_DIR/bin/render.sh"

###############################################################################
# UTILITIES
###############################################################################
die() { echo "apply-theme: $*" >&2; exit 1; }

trim() {
  # trims leading/trailing whitespace + strips CRLF
  local s="${1-}"
  s="${s//$'\r'/}"
  printf '%s' "$s" | xargs
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found in PATH"
}

ensure_dirs() {
  mkdir -p "$STATE_DIR" "$AUTO_DIR" "$STATE_DIR/current-colors"
}

pick_theme_rofi() {
  require_cmd rofi

  find -L "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort \
    | rofi -dmenu -i -p "Theme"
}

read_current_wallpaper_if_valid() {
  # prints wallpaper path if state file points to a real file, else prints nothing
  [[ -f "$CURRENT_WALLPAPER_TXT" ]] || return 0
  local candidate
  candidate="$(<"$CURRENT_WALLPAPER_TXT")"
  candidate="$(trim "$candidate")"
  [[ -n "$candidate" && -f "$candidate" ]] && printf '%s' "$candidate"
}

pick_random_wallpaper_from_theme() {
  # prints a random wallpaper file from theme wallpapers/, else prints nothing
  local theme_dir="${1:?theme_dir required}"
  local wp_dir="$theme_dir/wallpapers"

  [[ -d "$wp_dir" ]] || return 0

  mapfile -t wallpapers < <(
    find -L "$wp_dir" -type f \( \
      -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \
    \) | sort
  )

  (( ${#wallpapers[@]} > 0 )) || return 0
  printf '%s' "${wallpapers[RANDOM % ${#wallpapers[@]}]}"
}

resolve_theme_inputs() {
  # Outputs two values via stdout (newline-separated):
  #   1) palette_json_path
  #   2) wallpaper_path_or_empty
  local theme_name="${1:?theme_name required}"
  local theme_dir="$THEMES_DIR/$theme_name"

  [[ -d "$theme_dir" ]] || die "Theme not found: $theme_dir"

  local palette_json=""
  local wallpaper=""

  if [[ "$theme_name" == "auto-theme" || "$theme_name" == "auto" ]]; then
    require_cmd matugen

    [[ -f "$AUTO_WALLPAPER_FILE" ]] || die "auto-theme needs $AUTO_WALLPAPER_FILE set"
    wallpaper="$(trim "$(<"$AUTO_WALLPAPER_FILE")")"
    [[ -f "$wallpaper" ]] || die "Wallpaper not found: $wallpaper"

    # Generate palette.json from image
    matugen image "$wallpaper" -j > "$AUTO_PALETTE_JSON"
    palette_json="$AUTO_PALETTE_JSON"
  else
    palette_json="$theme_dir/palette.json"
    [[ -f "$palette_json" ]] || die "Missing palette.json in $theme_dir"

    # Keep current wallpaper if valid, else choose a random one from the theme
    wallpaper="$(read_current_wallpaper_if_valid || true)"
    if [[ -z "${wallpaper:-}" ]]; then
      wallpaper="$(pick_random_wallpaper_from_theme "$theme_dir" || true)"
    fi
  fi

  printf '%s\n%s\n' "$palette_json" "${wallpaper:-}"
}

persist_state() {
  local theme_name="${1:?theme_name required}"
  local wallpaper="${2-}"

  printf '%s' "$theme_name" > "$CURRENT_THEME_FILE"

  if [[ -n "${wallpaper:-}" ]]; then
    printf '%s\n' "$wallpaper" > "$CURRENT_WALLPAPER_TXT"
    ln -sfn "$wallpaper" "$CURRENT_WALLPAPER_LINK"
  fi
}

reload_apps_nonblocking() {
  # Never fail the theme apply just because a reload fails
  "$CONFIG_DIR/waybar/bin/launch.sh" >/dev/null 2>&1 || true
  "$CONFIG_DIR/swaync/bin/launch.sh" >/dev/null 2>&1 || true
  pkill wlogout >/dev/null 2>&1 || true
  command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
}

###############################################################################
# MAIN
###############################################################################
ensure_dirs
require_cmd jq
[[ -x "$RENDER_SCRIPT" ]] || die "render.sh not executable: $RENDER_SCRIPT"

theme_name="${1-}"
theme_name="$(trim "$theme_name")"

if [[ -z "$theme_name" ]]; then
  theme_name="$(pick_theme_rofi || true)"
  theme_name="$(trim "$theme_name")"
fi

# Cancelled picker / empty input
[[ -n "$theme_name" ]] || exit 0

readarray -t resolved < <(resolve_theme_inputs "$theme_name")
palette_json="${resolved[0]}"
wallpaper="${resolved[1]:-}"

persist_state "$theme_name" "$wallpaper"

# Render generated color outputs into state/current-colors/
"$RENDER_SCRIPT" "$palette_json"

reload_apps_nonblocking
exit 0
