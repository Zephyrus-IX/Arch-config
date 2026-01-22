#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 40-session-setup.sh
# Apply dotfiles using GNU Stow (with support for "real" local config roots)
#
# Goal:
# - Keep certain ~/.config/<app> directories REAL (not symlinks into repo)
# - Stow links inside them (e.g., layouts/, scripts/, themes/, etc.)
#
# Assumes:
# - repo already cloned
# - stow is installed
# - $HOME is available
# -----------------------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/omarchy-config/dotfiles}"

# Packages to stow
STOW_PACKAGES=(
  hypr
  swww
  kitty
  waybar
  swaync
)

# -----------------------------------------------------------------------------
# Real local roots (create these BEFORE stowing)
# If these exist as real directories, stow will link contents inside them
# instead of replacing the directory itself with a symlink.
# -----------------------------------------------------------------------------
REAL_CONFIG_ROOTS=(
  "$HOME/.config/waybar"
  "$HOME/.config/swaync"
)

# Optional: if you also want these patterns later, just add them:
# REAL_CONFIG_ROOTS+=("$HOME/.config/rofi" "$HOME/.config/hypr")

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "Dotfiles directory not found: $DOTFILES_DIR"
  echo "Skipping stow step."
  exit 0
fi

echo "Ensuring local (real) config roots exist:"
for dir in "${REAL_CONFIG_ROOTS[@]}"; do
  echo "  - $dir"
  mkdir -p "$dir"
done

cd "$DOTFILES_DIR"

echo "Applying dotfiles with stow:"
for pkg in "${STOW_PACKAGES[@]}"; do
  echo "  - $pkg"
done

# Stow into $HOME (so packages contain .config/... etc.)
stow -t "$HOME" "${STOW_PACKAGES[@]}"

echo "Done."
