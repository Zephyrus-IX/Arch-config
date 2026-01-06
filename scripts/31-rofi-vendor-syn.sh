#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

VENDOR_DIR="$ROOT_DIR/vendor/adi1090x-rofi"

# Submodule sources (match upstream installer intent)
SRC_ROFI="$VENDOR_DIR/files"
SRC_FONTS="$VENDOR_DIR/fonts"

# Stow package destinations (what stow will symlink into $HOME)
DST_ROFI="$ROOT_DIR/dotfiles/rofi/.config/rofi"
DST_FONTS="$ROOT_DIR/dotfiles/fonts/.local/share/fonts"

log() { printf '%s\n' "$*"; }

die() { echo "ERROR: $*" >&2; exit 1; }

command -v rsync >/dev/null 2>&1 || die "rsync is required"

[ -d "$VENDOR_DIR" ] || die "Missing submodule directory: $VENDOR_DIR (run git submodule update --init --recursive)"
[ -d "$SRC_ROFI" ]    || die "Expected rofi source not found: $SRC_ROFI"
[ -d "$SRC_FONTS" ]   || die "Expected fonts source not found: $SRC_FONTS"

log "==> Syncing adi1090x-rofi vendor content into stow packages"

# --- Rofi config mirror ---
log "==> Rofi configs:"
log "    FROM: $SRC_ROFI/"
log "    TO:   $DST_ROFI/"
mkdir -p "$DST_ROFI"
rsync -a --delete \
  --exclude '.git/' --exclude '.github/' \
  "$SRC_ROFI/" "$DST_ROFI/"

# Make shipped scripts executable (launchers often rely on this)
find "$DST_ROFI" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# --- Fonts mirror ---
log "==> Fonts:"
log "    FROM: $SRC_FONTS/"
log "    TO:   $DST_FONTS/"
mkdir -p "$DST_FONTS"
rsync -a --delete \
  --exclude '.git/' --exclude '.github/' \
  "$SRC_FONTS/" "$DST_FONTS/"

log "==> Done: vendor sync complete"
log "Next:"
log "  cd dotfiles && stow rofi fonts"
log "  fc-cache -f  (after first time fonts are stowed)"