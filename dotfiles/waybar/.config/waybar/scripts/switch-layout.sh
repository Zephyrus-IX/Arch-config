#!/usr/bin/env bash
set -euo pipefail

WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
LAYOUTS_DIR="$WAYBAR_DIR/layouts"
ACTIVE_DIR="$WAYBAR_DIR"

# sanity checks
if [[ ! -d "$LAYOUTS_DIR" ]]; then
  echo "Missing layouts dir: $LAYOUTS_DIR" >&2
  exit 1
fi

command -v rofi >/dev/null 2>&1 || { echo "rofi not found in PATH" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync not found in PATH" >&2; exit 1; }

# list layout folders (follow symlinks so stowed layouts show up)
layout="$(
  find -L "$LAYOUTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort \
    | rofi -dmenu -i -p "Waybar layout"
)"

[[ -z "${layout:-}" ]] && exit 0

src="$LAYOUTS_DIR/$layout"
if [[ ! -d "$src" ]]; then
  echo "Layout not found: $src" >&2
  exit 1
fi

# HARD RESET active dir (keep stowed folders)
# This prevents leftover modules/styles from previous layouts.
find "$ACTIVE_DIR" -mindepth 1 -maxdepth 1 \
  ! -name "layouts" \
  ! -name "scripts" \
  -exec rm -rf -- {} +

# Copy selected layout into ~/.config/waybar
rsync -a "$src"/ "$ACTIVE_DIR"/

# restart waybar to apply
pkill waybar >/dev/null 2>&1 || true
nohup waybar >/dev/null 2>&1 & disown
