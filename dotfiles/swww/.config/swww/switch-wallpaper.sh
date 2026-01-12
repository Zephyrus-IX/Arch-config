#!/usr/bin/env bash
set -euo pipefail

SYS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/system-theme"
STATE_DIR="$SYS_DIR/state"
THEMES_DIR="$SYS_DIR/themes"

mkdir -p "$STATE_DIR"

# Single source of truth: file that contains the theme name
THEME_FILE="$STATE_DIR/current-theme"

# Resolve active theme
if [[ -f "$THEME_FILE" ]]; then
  active="$(<"$THEME_FILE")"
  active="${active//$'\r'/}" # guard against CRLF
  active="$(printf '%s' "$active" | xargs)" # trim whitespace
else
  echo "No active theme found. Expected $THEME_FILE" >&2
  exit 1
fi

WALL_DIR="$THEMES_DIR/$active/wallpapers"
THEME_RASI="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/layouts/wall-picker/wall-picker.rasi"

if [[ ! -d "$WALL_DIR" ]]; then
  notify-send "Wallpaper" "No wallpapers folder for theme: $active"
  exit 1
fi

mapfile -d '' imgs < <(
  find -L "$WALL_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 | sort -z
)
((${#imgs[@]})) || { notify-send "Wallpaper" "No images in $WALL_DIR"; exit 1; }

entries=""
for f in "${imgs[@]}"; do
  base="$(basename "$f")"
  entries+="${base}\0icon\x1f${f}\n"
done

choice="$(printf '%b' "$entries" | rofi -dmenu -theme "$THEME_RASI" -p "$active")" || exit 0
[[ -n "$choice" ]] || exit 0

picked=""
for f in "${imgs[@]}"; do
  [[ "$(basename "$f")" == "$choice" ]] && picked="$f" && break
done
[[ -n "$picked" ]] || exit 0

# Apply (swww example)
if command -v swww >/dev/null 2>&1; then
  swww img "$picked" --transition-type any --transition-duration 0.6
else
  notify-send "Wallpaper" "Install swww or change script apply step"
fi

# Persist current wallpaper for consumers (hyprlock, scripts, etc.)
# - Symlink (best for hyprlock): ~/.config/system-theme/state/current-wallpaper
# - Text file (debug/optional):  ~/.config/system-theme/state/current-wallpaper.txt
ln -sfn "$picked" "$STATE_DIR/current-wallpaper"
printf '%s\n' "$picked" > "$STATE_DIR/current-wallpaper.txt"
