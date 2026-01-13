#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# compile-templates.sh
#
# Purpose:
#   Read a palette JSON (key -> hex color) and compile template files into
#   concrete outputs under: ~/.config/system-theme/state/current-colors/
#
# Usage:
#   compile-templates.sh /path/to/palette.json
#
# Template inputs (optional; only compiled if present):
#   ~/.config/system-theme/templates/
#     hypr-colors.conf.tmpl
#     waybar-colors.css.tmpl
#     rofi-colors.rasi.tmpl
#     swaync-colors.css.tmpl
#     wlogout-colors.css.tmpl
#     kitty-colors.conf.tmpl
#
# Outputs:
#   ~/.config/system-theme/state/current-colors/
#     hypr-colors.conf
#     waybar-colors.css
#     rofi-colors.rasi
#     swaync-colors.css
#     wlogout-colors.css
#     kitty-colors.conf
###############################################################################

###############################################################################
# PATHS / INPUT
###############################################################################
PALETTE_JSON="${1:?Usage: compile-templates.sh /path/to/palette.json}"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
SYS_DIR="$CONFIG_DIR/system-theme"

TEMPLATES_DIR="$SYS_DIR/templates"
OUTPUT_DIR="$SYS_DIR/state/current-colors"

###############################################################################
# UTILITIES
###############################################################################
die() { echo "compile-templates: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found in PATH"
}

ensure_paths() {
  [[ -f "$PALETTE_JSON" ]] || die "Palette not found: $PALETTE_JSON"
  mkdir -p "$OUTPUT_DIR"
}

hex_to_hypr_rgba() {
  # Converts:
  #   #RRGGBB   -> rgba(RRGGBBff)
  #   #RRGGBBAA -> rgba(RRGGBBAA)
  # Otherwise passthrough (already rgba(), etc.)
  local color="${1:-}"

  if [[ "$color" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    printf 'rgba(%sff)' "${color#\#}"
    return 0
  fi

  if [[ "$color" =~ ^#[0-9a-fA-F]{8}$ ]]; then
    printf 'rgba(%s)' "${color#\#}"
    return 0
  fi

  printf '%s' "$color"
}

export_palette_env() {
  # Exports environment variables for envsubst:
  #   <key>         = "#RRGGBB"
  #   <key>_hypr    = "rgba(RRGGBBff)"
  #
  # Ignores JSON _meta.
  local key val

  while IFS='=' read -r key val; do
    [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
    export "$key=$val"
    export "${key}_hypr=$(hex_to_hypr_rgba "$val")"
  done < <(
    jq -r '
      del(._meta)
      | to_entries[]
      | select(.value | type == "string")
      | "\(.key)=\(.value)"
    ' "$PALETTE_JSON"
  )
}

compile_template() {
  # compile_template <template_path> <output_path>
  local template_path="${1:?template_path required}"
  local output_path="${2:?output_path required}"

  [[ -f "$template_path" ]] || return 0
  envsubst < "$template_path" > "$output_path"
}

compile_hypr_template_special() {
  # Your hypr template needs a special post-step:
  # - It uses "@@" in place of "$" to avoid envsubst eating non-vars.
  # - After envsubst, convert "@@" back into "$".
  local template_path="$TEMPLATES_DIR/hypr-colors.conf.tmpl"
  local output_path="$OUTPUT_DIR/hypr-colors.conf"

  [[ -f "$template_path" ]] || return 0

  local tmp
  tmp="$(mktemp)"
  envsubst < "$template_path" > "$tmp"
  sed 's/^@@/\$/g' "$tmp" > "$output_path"
  rm -f "$tmp"
}

###############################################################################
# MAIN
###############################################################################
require_cmd jq
require_cmd envsubst
ensure_paths

export_palette_env

compile_hypr_template_special
compile_template "$TEMPLATES_DIR/waybar-colors.css.tmpl"  "$OUTPUT_DIR/waybar-colors.css"
compile_template "$TEMPLATES_DIR/rofi-colors.rasi.tmpl"   "$OUTPUT_DIR/rofi-colors.rasi"
compile_template "$TEMPLATES_DIR/swaync-colors.css.tmpl"  "$OUTPUT_DIR/swaync-colors.css"
compile_template "$TEMPLATES_DIR/wlogout-colors.css.tmpl" "$OUTPUT_DIR/wlogout-colors.css"
compile_template "$TEMPLATES_DIR/kitty-colors.conf.tmpl"  "$OUTPUT_DIR/kitty-colors.conf"

exit 0