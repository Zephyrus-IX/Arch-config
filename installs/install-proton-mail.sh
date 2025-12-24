#!/bin/sh

# If dependencies are needed grab them first
echo "Ensuring dependencies are met..."

if sudo pacman -Qi bash &> /dev/null; then
  echo "bash is already installed"
else 
  sudo pacman -S --noconfirm --needed bash
fi

if sudo pacman -Qi electron36 &> /dev/null; then
  echo "electron36 is already installed"
else 
  sudo pacman -S --noconfirm --needed electron36
fi

if sudo pacman -Qi hicolor-icon-theme &> /dev/null; then
  echo "hicolor-icon-theme is already installed"
else 
  sudo pacman -S --noconfirm --needed hicolor-icon-theme
fi

if sudo pacman -Qi xdg-utils &> /dev/null; then
  echo "xdg-utils is already installed"
else 
  sudo pacman -S --noconfirm --needed xdg-utils
fi


# Check if nord vpn is already installed
if pacman -Qi proton-mail-bin &> /dev/null; then
  echo "nordvpn-bin is already installed"
else
  yay -S --noconfirm --needed proton-mail-bin
fi
