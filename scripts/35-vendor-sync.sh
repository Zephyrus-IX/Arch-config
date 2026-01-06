#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

SUBMODULE_DIR="$ROOT_DIR/vendor/adi1090x-rofi"
ROFI_STOW_DIR="$ROOT_DIR/dotfiles/rofi"
TARGET_ROFI_CFG="$ROFI_STOW_DIR/.config/rofi"
TARGET_FONTS="$ROFI_STOW_DIR/.local/share/fonts"

# Only run if the submodule exists (repo cloned with submodules)
if [[ ! -d "$SUBMODULE_DIR" ]]; then
  echo "↷ Submodule not found: $SUBMODULE_DIR (skipping rofi vendor sync)"
  exit 0
fi

# Ensure expected upstream structure exists
if [[ ! -d "$SUBMODULE_DIR/files" ]] || [[ ! -d "$SUBMODULE_DIR/fonts" ]]; then
  echo "✖ Submodule missing expected folders (files/ or fonts/)."
  echo "  Check submodule path: $SUBMODULE_DIR"
  exit 1
fi

mkdir -p "$TARGET_ROFI_CFG" "$TARGET_FONTS"

echo "▶ Syncing rofi configs into stow package..."
# Copy contents (idempotent): overwrite existing to match vendor snapshot
cp -a "$SUBMODULE_DIR/files/." "$TARGET_ROFI_CFG/"

echo "▶ Syncing fonts into stow package..."
cp -a "$SUBMODULE_DIR/fonts/." "$TARGET_FONTS/"

echo "✔ Vendor sync complete (rofi + fonts)."
