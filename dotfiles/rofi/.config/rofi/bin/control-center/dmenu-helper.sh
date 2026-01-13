#!/usr/bin/env bash
set -euo pipefail

# Show a rofi dmenu with consistent options and ONE back key.
# Args:
#   $1 = prompt (optional)
#   $2 = theme path (optional; if empty, no -theme flag is used)
rofi_dmenu() {
  local prompt="${1:-Menu}"
  local theme="${2:-}"

  local -a cmd=(
    rofi -dmenu -i -show-icons
    -p "$prompt"
    -kb-custom-1 "Alt+BackSpace"
  )

  if [[ -n "$theme" ]]; then
    cmd+=(-theme "$theme")
  fi

  "${cmd[@]}"
}

# Return codes:
# 10 = kb-custom-1
is_back() { [[ "${1:-0}" -eq 10 ]]; }
