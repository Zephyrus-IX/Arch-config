#!/usr/bin/env bash
set -euo pipefail

SWAYNC_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync"
LAYOUTS_DIR="$SWAYNC_DIR/layouts"
ACTIVE_DIR="$SWAYNC_DIR"

# sanity checks
if [[ ! -d "$LAYOUTS_DIR" ]]; then
  echo "Missing layouts dir: $LAYOUTS_DIR" >&2
  exit 1
fi

# list layout folders (follow symlinks so stowed layouts show up)
layout="$(
  find -L "$LAYOUTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort \
    | rofi -dmenu -i -p "SwayNC layout"
)"

[[ -z "${layout:-}" ]] && exit 0

src="$LAYOUTS_DIR/$layout"

# Safety: only allow directories (also follow symlinks)
if [[ ! -d "$src" ]]; then
  echo "Layout not found: $src" >&2
  exit 1
fi

# HARD RESET active dir (keep stowed folders)
# This deletes any previous layout's files so you never get leftovers.
find "$ACTIVE_DIR" -mindepth 1 -maxdepth 1 \
  ! -name "layouts" \
  ! -name "bin" \
  -exec rm -rf -- {} +

# Copy selected layout into ~/.config/swaync
# (layouts/ and scripts/ remain as-is)
rsync -a "$src"/ "$ACTIVE_DIR"/

# restart swaync to apply
pkill swaync >/dev/null 2>&1 || true
nohup swaync >/dev/null 2>&1 & disown
