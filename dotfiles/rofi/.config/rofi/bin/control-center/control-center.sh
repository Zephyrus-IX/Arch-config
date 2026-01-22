#!/usr/bin/env bash
set -euo pipefail

################################################################################################################################
# DEFAULTS AND CONFIG
################################################################################################################################
ROFI_THEME_DEFAULT="$HOME/control-center/control-center.rasi"
PROMPT_DEFAULT="${PROMPT:-Control Center | }"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAYOUTS_DIR="$SCRIPT_DIR/../../layouts"

CURRENT_THEME_FILE="$HOME/.config/system-theme/state/current-theme"
if [[ -f "$CURRENT_THEME_FILE" ]]; then
  CURRENT_THEME="$(<"$CURRENT_THEME_FILE")"
  CURRENT_THEME="${CURRENT_THEME//$'\r'/}"
  CURRENT_THEME="$(printf '%s' "$CURRENT_THEME" | xargs)"
else
  CURRENT_THEME=""
fi

################################################################################################################################
# SOURCE HELPER FUNCTIONS/FILES
################################################################################################################################
source "$SCRIPT_DIR/dmenu-helper.sh"
source "$SCRIPT_DIR/menus.sh"

################################################################################################################################
# MENU NAVIGATION FUNCTIONS (Write once, should never need to adjust)
################################################################################################################################

_menu_var() {
  local kind="$1" name="$2"
  printf 'MENU_%s_%s' "$kind" "$name"
}

_menu_get_prompt() {
  local v; v="$(_menu_var PROMPT "$1")"
  printf '%s' "${!v:-$PROMPT_DEFAULT}"
}

_menu_get_theme() {
  local v; v="$(_menu_var THEME "$1")"
  printf '%s' "${!v:-$ROFI_THEME_DEFAULT}"
}

_menu_get_options_var() {
  _menu_var OPTIONS "$1"
}

_list_layouts_with_icons() {
  local layouts_root="${1:?layouts_root required}"
  local name layout_dir icon

  # Get folder names sorted naturally (style-2 before style-10)
  while IFS= read -r name; do
    layout_dir="$layouts_root/$name/"

    # Preferred icon names:
    #   1) preview.png
    #   2) <foldername>.png
    icon="$layout_dir/preview.png"
    [[ -f "$icon" ]] || icon="$layout_dir/$name.png"

    # Fallback: first image in folder
    if [[ ! -f "$icon" ]]; then
      shopt -s nullglob
      local first=()
      first=("$layout_dir"*.png "$layout_dir"*.jpg "$layout_dir"*.jpeg "$layout_dir"*.webp)
      shopt -u nullglob
      [[ -f "${first[0]:-}" ]] && icon="${first[0]}"
    fi

    if [[ -f "$icon" ]]; then
      printf '%s\0icon\x1f%s\n' "$name" "$icon"
    else
      printf '%s\n' "$name"
    fi
  done < <(
    find -L "$layouts_root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V
  )
}

_list_image_files_with_icons() {
  local dir="${1:?dir required}"
  local f base ext

  shopt -s nullglob
  for f in "$dir"/*; do
    [[ -f "$f" ]] || continue
    ext="${f##*.}"
    case "${ext,,}" in
      png|jpg|jpeg|webp) ;;
      *) continue ;;
    esac
    base="$(basename "$f")"
    printf '%s\0icon\x1f%s\n' "$base" "$f"
  done
}

_menu_labels_from_array() {
  local -n arr="$1"   # <-- CRITICAL: nameref to the array variable name you pass in
  local entry raw_label

  for entry in "${arr[@]}"; do
    raw_label="${entry%%|*}"
    # Print with %b so \0icon\x1f... becomes real rofi metadata bytes
    printf '%b\n' "$raw_label"
  done
}

_menu_action_from_array() {
  local -n arr="$1"
  local chosen="$2"
  local entry raw_label plain_label action

  for entry in "${arr[@]}"; do
    raw_label="${entry%%|*}"
    action="${entry#*|}"

    # Strip the literal "\0icon..." portion for comparison with rofi's returned label
    plain_label="${raw_label%%\\0icon*}"

    [[ "$plain_label" == "$chosen" ]] && { printf '%s' "$action"; return 0; }
  done
  return 1
}

# Dynamic picker:
# - folder mode if root contains subdirs
# - file mode otherwise
#
# Return codes:
#   0  : handled/applied
#   1  : Esc/cancel
#   10 : back (Alt+BackSpace via helper)
_run_dynamic_menu() {
  local menu_name="$1"
  local dyn_spec="$2"

  # Strip dyn:
  dyn_spec="${dyn_spec#dyn:}"

  local layouts_root apply_script prompt theme rest
  layouts_root="${dyn_spec%%|*}"
  rest="${dyn_spec#*|}"
  apply_script="${rest%%|*}"
  rest="${rest#*|}"

  prompt="$(_menu_get_prompt "$menu_name")"
  theme="$(_menu_get_theme "$menu_name")"

  [[ -d "$layouts_root" ]] || { echo "Dynamic menu root not found: $layouts_root" >&2; return 1; }
  [[ -x "$apply_script" ]] || { echo "Dynamic menu apply script not executable: $apply_script" >&2; return 1; }

  local selection exit_code

  if compgen -G "$layouts_root"/*/ >/dev/null; then
    selection="$(_list_layouts_with_icons "$layouts_root" | rofi_dmenu "$prompt" "$theme")" || exit_code=$?
    exit_code="${exit_code:-0}"

    [[ $exit_code -eq 1 ]] && return 1
    is_back "$exit_code" && return 10
    [[ -z "${selection:-}" ]] && return 0

    # ------------------------------------------------------------
    # NEW: If selected folder contains subfolders, do a second picker
    # This supports structures like:
    #   root/type-1/style-7/
    # while preserving existing one-level behavior (wlogout, etc.)
    # ------------------------------------------------------------
    local selected_dir="$layouts_root/$selection"

    if compgen -G "$selected_dir"/*/ >/dev/null; then
      local selection2 exit_code2
      selection2="$(_list_layouts_with_icons "$selected_dir" | rofi_dmenu "$prompt" "$theme")" || exit_code2=$?
      exit_code2="${exit_code2:-0}"

      [[ $exit_code2 -eq 1 ]] && return 1
      is_back "$exit_code2" && return 10
      [[ -z "${selection2:-}" ]] && return 0

      # Pass as "type/style" (single arg) so apply scripts can parse easily
      "$apply_script" "$selection/$selection2"
      return 0
    fi

    # One-level folder layout (existing behavior)
    "$apply_script" "$selection"
    return 0
  else
    selection="$(_list_image_files_with_icons "$layouts_root" | rofi_dmenu "$prompt" "$theme")" || exit_code=$?
    exit_code="${exit_code:-0}"

    [[ $exit_code -eq 1 ]] && return 1
    is_back "$exit_code" && return 10
    [[ -z "${selection:-}" ]] && return 0

    "$apply_script" "$layouts_root/$selection"
    return 0
  fi
}

################################################################################################################################
# MAIN / EXEC
################################################################################################################################
run_menu() {
  local menu_name="${1:-main}"
  local opts_var prompt theme

  opts_var="$(_menu_get_options_var "$menu_name")"
  declare -p "$opts_var" >/dev/null 2>&1 || {
    echo "Unknown menu: $menu_name (missing $opts_var)" >&2
    return 1
  }

  prompt="$(_menu_get_prompt "$menu_name")"
  theme="$(_menu_get_theme "$menu_name")"

  while true; do
    local chosen rc
    local -n opts_ref="$opts_var"

    # Dynamic menu: MENU_OPTIONS_<name>[0] = dyn:...
    if [[ "${#opts_ref[@]}" -ge 1 && "${opts_ref[0]}" == dyn:* ]]; then
      rc=0
      _run_dynamic_menu "$menu_name" "${opts_ref[0]}" || rc=$?
      rc="${rc:-0}"

      # Esc: exit entire control center
      [[ $rc -eq 1 ]] && exit 0

      # Back: return to parent menu
      is_back "$rc" && return 0
      [[ $rc -eq 10 ]] && return 0

      # Success (applied): exit entire control center
      [[ $rc -eq 0 ]] && exit 0

      # Any other code: exit (safe default)
      exit 0
    fi

    # Static menu: show labels and map selection -> action
    local action

    rc=0
    chosen="$(_menu_labels_from_array "$opts_var" | rofi_dmenu "$prompt" "$theme")" || rc=$?
    rc="${rc:-0}"

    # Esc: exit entire control center
    [[ $rc -eq 1 ]] && exit 0

    # Back: return to parent menu
    is_back "$rc" && return 0

    [[ -z "${chosen:-}" ]] && continue

    action="$(_menu_action_from_array "$opts_var" "$chosen")" || continue

    case "$action" in
      menu:*)
        run_menu "${action#menu:}"
        ;;
      run:*)
        bash -lc "${action#run:}"
        exit 0
        ;;
      *)
        "$action"
        exit 0
        ;;
    esac
  done
}

run_menu main
