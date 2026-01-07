#!/usr/bin/env bash
set -euo pipefail

WLOGOUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wlogout"
LAYOUTS_DIR="$WLOGOUT_DIR/layouts"
ACTIVE_DIR="$WLOGOUT_DIR"

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
    | rofi -dmenu -i -p "wlogout layout"
)"

[[ -z "${layout:-}" ]] && exit 0

src="$LAYOUTS_DIR/$layout"
if [[ ! -d "$src" ]]; then
  echo "Layout not found: $src" >&2
  exit 1
fi

# HARD RESET active dir (keep stowed folders)
# Prevent leftovers from previous layouts.
find "$ACTIVE_DIR" -mindepth 1 -maxdepth 1 \
  ! -name "layouts" \
  ! -name "bin" \
  -exec rm -rf -- {} +

# Copy selected layout into ~/.config/wlogout
rsync -a "$src"/ "$ACTIVE_DIR"/

# If wlogout is currently open, close it so next launch uses new files
pkill wlogout >/dev/null 2>&1 || true
