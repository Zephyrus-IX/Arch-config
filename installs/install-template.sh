#!/bin/sh
set -eu

###############################################################################
# CONFIG — change only this section
###############################################################################
# apps | cosmetic
INSTALL_TYPE=apps


PACMAN_PKGS="
"

OPTIONAL_PKGS="
"

AUR_PKGS="
"
###############################################################################

has_words() {
  # returns 0 if $1 contains any non-whitespace characters
  printf "%s" "$1" | tr -d '[:space:]' | grep -q .
}

install_pacman() {
  sudo pacman -S --noconfirm --needed "$@"
}

install_aur() {
  if command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm --needed "$@"
  elif command -v paru >/dev/null 2>&1; then
    paru -S --noconfirm --needed "$@"
  else
    echo "AUR helper not found (yay/paru)."
    return 1
  fi
}

# Main
if has_words "$PACMAN_PKGS"; then
  # word-splitting intended here
  install_pacman $PACMAN_PKGS
fi

if has_words "$OPTIONAL_PKGS"; then
  install_pacman $OPTIONAL_PKGS || true
fi

if has_words "$AUR_PKGS"; then
  install_aur $AUR_PKGS
fi
