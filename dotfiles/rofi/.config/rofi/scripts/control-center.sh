#!/usr/bin/env bash
set -euo pipefail

menu="$(
  printf "%s\n" \
    "SwayNC → Layout" \
    "Waybar → Layout" \
    "Wallpaper → Select" \
    | rofi -dmenu -i -p "Control Center"
)"

[[ -z "${menu:-}" ]] && exit 0

case "$menu" in
  "SwayNC → Layout")  ~/.config/swaync/scripts/switch-layout.sh ;;
  "Waybar → Layout")  ~/.config/waybar/scripts/switch-layout.sh ;;
  "Wallpaper → Select") ~/.config/swww/scripts/switch-wallpaper.sh ;;
esac