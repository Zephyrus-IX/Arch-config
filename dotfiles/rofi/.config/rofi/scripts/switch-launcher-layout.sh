#!/usr/bin/env bash
set -euo pipefail

ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
LAUNCHER_LAYOUTS="$ROFI_DIR/layouts/launchers"
TARGET="$ROFI_DIR/scripts/launcher.sh"

# Theme for the FIRST menu (types, needs text)
ROFI_TYPE_THEME="${ROFI_TYPE_THEME:-$ROFI_DIR/layouts/control-center/control-center.rasi}"
# Theme for the SECOND menu (styles, image grid)
ROFI_STYLE_THEME="${ROFI_STYLE_THEME:-$ROFI_DIR/layouts/launchers/launcher-picker.rasi}"

command -v rofi >/dev/null 2>&1 || { echo "rofi not found in PATH" >&2; exit 1; }
[[ -d "$LAUNCHER_LAYOUTS" ]] || { echo "Missing launcher layouts dir: $LAUNCHER_LAYOUTS" >&2; exit 1; }
mkdir -p "$ROFI_DIR/scripts"

if [[ -L "$TARGET" ]]; then
  rm -f "$TARGET"
fi

# -----------------------
# Pick launcher type (TEXT)
# -----------------------
type="$(
  find -L "$LAUNCHER_LAYOUTS" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | sort -V \
    | rofi -dmenu -i -p "Launcher type" -theme "$ROFI_TYPE_THEME"
)"
[[ -z "${type:-}" ]] && exit 0

type_dir="$LAUNCHER_LAYOUTS/$type"
[[ -d "$type_dir" ]] || { echo "Type not found: $type_dir" >&2; exit 1; }

# -----------------------
# Pick style (IMAGE GRID)
# -----------------------
entries=""
while IFS= read -r -d '' d; do
  style="$(basename "$d")"
  png="$d/$style.png"
  rasi="$d/$style.rasi"
  [[ -f "$rasi" ]] || continue

  if [[ -f "$png" ]]; then
    entries+="${style}\0icon\x1f${png}\n"
  else
    entries+="${style}\n"
  fi
done < <(find -L "$type_dir" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

style="$(
  printf '%b' "$entries" \
    | rofi -dmenu -i -p "Style ($type)" -theme "$ROFI_STYLE_THEME"
)"
[[ -z "${style:-}" ]] && exit 0

style_rasi="$type_dir/$style/$style.rasi"
[[ -f "$style_rasi" ]] || { echo "Missing rasi: $style_rasi" >&2; exit 1; }

cat > "$TARGET" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec rofi -show drun -theme "\$HOME/.config/rofi/layouts/launchers/$type/$style/$style.rasi"
EOF

chmod +x "$TARGET"
notify-send "Rofi Launcher" "Set: $type / $style"
