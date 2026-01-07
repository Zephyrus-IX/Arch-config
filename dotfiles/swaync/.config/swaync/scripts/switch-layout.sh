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

# list layout folders
layout="$(
  find "$LAYOUTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort \
    | rofi -dmenu -i -p "SwayNC layout"
)"

[[ -z "${layout:-}" ]] && exit 0

src="$LAYOUTS_DIR/$layout"

# Safety: only allow directories
if [[ ! -d "$src" ]]; then
  echo "Layout not found: $src" >&2
  exit 1
fi

# Copy layout contents into active swaync config
# Expect layout folder to contain config.json, style.css, icons/, themes/, etc.
rsync -a --delete \
  --exclude "layouts/" \
  --exclude "scripts/" \
  "$src"/ "$ACTIVE_DIR"/

# restart swaync to apply
pkill swaync >/dev/null 2>&1 || true
nohup swaync >/dev/null 2>&1 & disown
