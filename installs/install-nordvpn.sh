#!/bin/sh

# If dependencies are needed grab them first
if pacman -Qi wget &> /dev/null; then
  echo "wget is already installed"
else 
  pacman -S --noconfirm --needed wget
fi


# Check if nord vpn is already installed
if pacman -Qi nordvpn &> /dev/null; then
  echo "nordvpn is already installed"
else
  yay -S --noconfirm --needed nordvpn
fi
