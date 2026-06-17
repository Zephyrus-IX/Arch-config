#!/usr/bin/env bash
set -euo pipefail

WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
LAYOUTS_DIR="$WAYBAR_DIR/layouts"
ACTIVE_DIR="$WAYBAR_DIR"
VARS_FILE="$WAYBAR_DIR/bin/system-vars.env"

# sanity checks
if [[ ! -d "$LAYOUTS_DIR" ]]; then
  echo "Missing layouts dir: $LAYOUTS_DIR" >&2
  exit 1
fi

command -v rofi >/dev/null 2>&1 || { echo "rofi not found in PATH" >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync not found in PATH" >&2; exit 1; }
command -v envsubst >/dev/null 2>&1 || { echo "envsubst not found (package: gettext)" >&2; exit 1; }

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
  ! -name "bin" \
  -exec rm -rf -- {} +

# Copy selected layout into ~/.config/waybar
rsync -a "$src"/ "$ACTIVE_DIR"/

# ----------------------------
# Template rendering (merged)
# ----------------------------
# Load system vars if present
if [[ -f "$VARS_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$VARS_FILE"
  set +a
else
  echo "Warning: vars file not found, skipping templating: $VARS_FILE" >&2
fi

render_if_needed() {
  local in_file="$1"
  local out_file="$2"

  [[ -f "$in_file" ]] || return 0

  # If vars weren't loaded, envsubst will still run but only replace exported vars.
  envsubst < "$in_file" > "$out_file"
}

# Prefer explicit .in templates if they exist, otherwise render the copied files in-place
if [[ -f "$ACTIVE_DIR/config.jsonc.in" ]]; then
  render_if_needed "$ACTIVE_DIR/config.jsonc.in" "$ACTIVE_DIR/config.jsonc"
fi
if [[ -f "$ACTIVE_DIR/style.css.in" ]]; then
  render_if_needed "$ACTIVE_DIR/style.css.in" "$ACTIVE_DIR/style.css"
fi

# If you don't use .in files, but your config/style contain ${VARS},
# render them into themselves safely via a temp file.
if [[ -f "$ACTIVE_DIR/config.jsonc" && ! -f "$ACTIVE_DIR/config.jsonc.in" && -f "$VARS_FILE" ]]; then
  tmp="$(mktemp)"
  envsubst < "$ACTIVE_DIR/config.jsonc" > "$tmp"
  mv "$tmp" "$ACTIVE_DIR/config.jsonc"
fi

if [[ -f "$ACTIVE_DIR/style.css" && ! -f "$ACTIVE_DIR/style.css.in" && -f "$VARS_FILE" ]]; then
  tmp="$(mktemp)"
  envsubst < "$ACTIVE_DIR/style.css" > "$tmp"
  mv "$tmp" "$ACTIVE_DIR/style.css"
fi

# restart waybar to apply
pkill waybar >/dev/null 2>&1 || true
nohup waybar >/dev/null 2>&1 & disown
