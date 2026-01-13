#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# apply-layout.sh (wlogout)
#
# Usage:
#   apply-layout.sh "<layout-name>"   # control center calls this form
#   apply-layout.sh                  # optional: interactive rofi picker
#
# Layout structure:
#   ~/.config/wlogout/layouts/<layout-name>/...
#   (preview.* files are ignored during apply)
###############################################################################

###############################################################################
# PATHS / DEFAULTS (edit here)
###############################################################################
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

WLOGOUT_DIR="$CONFIG_DIR/wlogout"
LAYOUTS_DIR="$WLOGOUT_DIR/layouts"
ACTIVE_DIR="$WLOGOUT_DIR"

###############################################################################
# UTILITIES
###############################################################################
die() { echo "wlogout apply-layout: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found in PATH"
}

trim() {
  local s="${1-}"
  s="${s//$'\r'/}"
  printf '%s' "$s" | xargs
}

pick_layout_rofi() {
  require_cmd rofi

  find -L "$LAYOUTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort \
    | rofi -dmenu -i -p "Wlogout layout"
}

reset_active_dir() {
  # Hard reset active dir, but keep stowed folders like layouts/ and bin/
  find "$ACTIVE_DIR" -mindepth 1 -maxdepth 1 \
    ! -name "layouts" \
    ! -name "bin" \
    -exec rm -rf -- {} +
}

apply_layout() {
  local layout_name="${1:?layout_name required}"
  local src_dir="$LAYOUTS_DIR/$layout_name"

  [[ -d "$src_dir" ]] || die "Layout not found: $src_dir"

  reset_active_dir

  # Copy selected layout into ~/.config/wlogout
  # Exclude preview.* files anywhere in the tree
  rsync -a --exclude='preview.*' "$src_dir"/ "$ACTIVE_DIR"/

  # If wlogout is currently open, close it so next launch uses new files
  pkill wlogout >/dev/null 2>&1 || true
}

###############################################################################
# MAIN
###############################################################################
[[ -d "$LAYOUTS_DIR" ]] || die "Missing layouts dir: $LAYOUTS_DIR"
require_cmd rsync

layout_name="${1-}"
layout_name="$(trim "$layout_name")"

if [[ -z "$layout_name" ]]; then
  layout_name="$(pick_layout_rofi || true)"
  layout_name="$(trim "$layout_name")"
fi

# Cancelled picker / empty input
[[ -n "$layout_name" ]] || exit 0

apply_layout "$layout_name"
exit 0
