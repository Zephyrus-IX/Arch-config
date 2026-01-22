#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# APPLY ROFI LAUNCHER (Control Center compatible)
#
# Usage:
#   apply-launcher.sh                 # interactive (pick type, then style)
#   apply-launcher.sh <type> <style>  # non-interactive (apply directly)
#
# - Control Center should call this with <type> <style>.
# - Running with no args opens the rofi menus.
###############################################################################

###############################################################################
# CONFIG / PATHS (single place to edit later)
###############################################################################
ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
LAUNCHER_LAYOUTS_DIR="$ROFI_DIR/layouts/launchers"
TARGET_LAUNCHER="$ROFI_DIR/bin/launcher.sh"

# Theme for the FIRST menu (types, needs text)
ROFI_TYPE_THEME="${ROFI_TYPE_THEME:-$ROFI_DIR/layouts/control-center/control-center.rasi}"
# Theme for the SECOND menu (styles, image grid)
ROFI_STYLE_THEME="${ROFI_STYLE_THEME:-$ROFI_DIR/layouts/launchers/launcher-picker.rasi}"

# Notifications (can disable in Control Center if you want)
NOTIFY="${NOTIFY:-1}"

###############################################################################
# HELPERS (small + readable)
###############################################################################
die() {
  echo "apply-launcher: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found in PATH"
}

ensure_dirs() {
  [[ -d "$LAUNCHER_LAYOUTS_DIR" ]] || die "launcher layouts dir not found: $LAUNCHER_LAYOUTS_DIR"
  mkdir -p "$ROFI_DIR/scripts"
}

list_types() {
  find -L "$LAUNCHER_LAYOUTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort -V
}

type_dir() {
  local type="${1:?type required}"
  printf '%s' "$LAUNCHER_LAYOUTS_DIR/$type"
}

list_styles_for_type() {
  local type="${1:?type required}"
  local dir
  dir="$(type_dir "$type")"
  [[ -d "$dir" ]] || die "type not found: $dir"

  find -L "$dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort -V
}

style_rasi_path() {
  local type="${1:?type required}"
  local style="${2:?style required}"
  printf '%s' "$LAUNCHER_LAYOUTS_DIR/$type/$style/$style.rasi"
}

style_png_path() {
  local type="${1:?type required}"
  local style="${2:?style required}"
  printf '%s' "$LAUNCHER_LAYOUTS_DIR/$type/$style/$style.png"
}

build_target_launcher() {
  local type="${1:?type required}"
  local style="${2:?style required}"

  local rasi
  rasi="$(style_rasi_path "$type" "$style")"
  [[ -f "$rasi" ]] || die "missing rasi: $rasi"

  # Avoid symlink gotchas
  if [[ -L "$TARGET_LAUNCHER" ]]; then
    rm -f "$TARGET_LAUNCHER"
  fi

  # Atomic write (never leave partial file)
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec rofi -show drun -theme "\$HOME/.config/rofi/layouts/launchers/$type/$style/$style.rasi"
EOF
  chmod +x "$tmp"
  mv -f "$tmp" "$TARGET_LAUNCHER"
}

notify_applied() {
  local type="${1:?type required}"
  local style="${2:?style required}"

  [[ "$NOTIFY" == "1" ]] || return 0
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send "Rofi Launcher" "Set: $type / $style"
}

pick_type_interactive() {
  need_cmd rofi

  local type
  type="$(
    list_types \
      | rofi -dmenu -i -p "Launcher type" -theme "$ROFI_TYPE_THEME"
  )"
  [[ -n "${type:-}" ]] || exit 0
  printf '%s' "$type"
}

pick_style_interactive() {
  need_cmd rofi

  local type="${1:?type required}"
  local dir
  dir="$(type_dir "$type")"
  [[ -d "$dir" ]] || die "type not found: $dir"

  local entries=""
  while IFS= read -r -d '' d; do
    local style png rasi
    style="$(basename "$d")"
    rasi="$d/$style.rasi"
    png="$d/$style.png"
    [[ -f "$rasi" ]] || continue

    if [[ -f "$png" ]]; then
      entries+="${style}\0icon\x1f${png}\n"
    else
      entries+="${style}\n"
    fi
  done < <(find -L "$dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

  local style
  style="$(
    printf '%b' "$entries" \
      | rofi -dmenu -i -p "Style ($type)" -theme "$ROFI_STYLE_THEME"
  )"
  [[ -n "${style:-}" ]] || exit 0
  printf '%s' "$style"
}

apply_launcher() {
  local type="${1:?type required}"
  local style="${2:?style required}"

  build_target_launcher "$type" "$style"
  notify_applied "$type" "$style"
}

###############################################################################
# MAIN
###############################################################################
main() {
  ensure_dirs

  local a1="${1:-}"
  local a2="${2:-}"

  local type=""
  local style=""

  # Control Center mode: apply directly
  # Accept:
  #   1) <type> <style>
  #   2) <type>/<style>
  if [[ -n "$a1" || -n "$a2" ]]; then
    if [[ -n "$a1" && -n "$a2" ]]; then
      type="$a1"
      style="$a2"
    elif [[ -n "$a1" && "$a1" == */* ]]; then
      type="${a1%%/*}"
      style="${a1##*/}"
    else
      die "expected: <type> <style> OR <type>/<style>"
    fi

    [[ -n "$type" && -n "$style" ]] || die "invalid selection"
    apply_launcher "$type" "$style"
    exit 0
  fi

  # Interactive mode: pick type then style
  type="$(pick_type_interactive)"
  style="$(pick_style_interactive "$type")"
  apply_launcher "$type" "$style"
}

main "$@"
