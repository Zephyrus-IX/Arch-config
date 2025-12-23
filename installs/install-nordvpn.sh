#!/bin/sh

# If dependencies are needed grab them first
if sudo pacman -Qi wget &> /dev/null; then
  echo "wget is already installed"
else 
  sudo pacman -S --noconfirm --needed wget
fi


# Check if nord vpn is already installed
if pacman -Qi nordvpn-bin &> /dev/null; then
  echo "nordvpn-bin is already installed"
else
  yay -S --noconfirm --needed nordvpn-bin
fi
