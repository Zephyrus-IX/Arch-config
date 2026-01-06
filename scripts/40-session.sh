#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Apply dotfiles using GNU Stow
# -----------------------------------------------------------------------------
# Assumes:
# - repo already cloned
# - stow is installed
# - user HOME is available
# -----------------------------------------------------------------------------

DOTFILES_DIR="$HOME/omarchy-config/dotfiles"

# Stow packages to apply for this user/session
STOW_PACKAGES=(
  hypr
  swww
  kitty
  waybar
)

if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "Dotfiles directory not found: $DOTFILES_DIR"
  echo "Skipping stow step."
  exit 0
fi

cd "$DOTFILES_DIR"

echo "Applying dotfiles with stow:"
for pkg in "${STOW_PACKAGES[@]}"; do
  echo "  - $pkg"
done

stow -t "$HOME" "${STOW_PACKAGES[@]}"
