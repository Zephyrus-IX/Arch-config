#!/usr/bin/env bash
set -e

# Call stow to install dotfiles from the repository
DOTFILES_DIR="$HOME/omarchy-config/dotfiles"   # adjust to your repo location

if [ -d "$DOTFILES_DIR" ]; then
  cd "$DOTFILES_DIR"
  stow -t "$HOME" hypr swww
fi
