#!/usr/bin/env bash
set -euo pipefail

ROFI_THEME="${ROFI_THEME:-$HOME/.config/rofi/layouts/control-center/control-center.rasi}"
PROMPT="${PROMPT:-Control Center | }"

ENTRIES=(
  "SwayNC → Layout|$HOME/.config/swaync/bin/switch-layout.sh"
  "Waybar → Layout|$HOME/.config/waybar/bin/switch-layout.sh"
  "Wallpaper → Select|$HOME/.config/rofi/scripts/switch-wallpaper.sh"
  "Wlogout → Layout|$HOME/.config/wlogout/bin/switch-layout.sh"
  "Rofi App Launcher → Layout|$HOME/.config/rofi/scripts/switch-launcher-layout.sh"
  "Rofi Theme Switcher → Theme|$HOME/.config/system-theme/bin/apply-theme.sh"
)

menu="$(printf '%s\n' "${ENTRIES[@]%%|*}" | rofi -dmenu -i -p "$PROMPT" -theme "$ROFI_THEME")"
[[ -z "${menu:-}" ]] && exit 0

for entry in "${ENTRIES[@]}"; do
  label="${entry%%|*}"
  cmd="${entry#*|}"
  if [[ "$label" == "$menu" ]]; then
    # Run directly (preserves your Wayland session env)
    exec "$cmd"
  fi
done
