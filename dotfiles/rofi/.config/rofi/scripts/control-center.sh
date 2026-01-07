#!/usr/bin/env bash
set -euo pipefail

menu="$(
  printf "%s\n" \
    "SwayNC → Layout" \
    "Waybar → Layout" \
    "Wallpaper → Select" \
    "Rofi App Launcher → Layout" \
    | rofi -dmenu -i -p "Control Center"
)"

[[ -z "${menu:-}" ]] && exit 0

case "$menu" in
  "SwayNC → Layout")  ~/.config/swaync/bin/switch-layout.sh ;;
  "Waybar → Layout")  ~/.config/waybar/bin/switch-layout.sh ;;
  "Wallpaper → Select") ~/.config/swww/bin/switch-wallpaper.sh ;;
  "Rofi App Launcher → Layout") ~/.config/rofi/scripts/switch-launcher-layout.sh ;;
esac