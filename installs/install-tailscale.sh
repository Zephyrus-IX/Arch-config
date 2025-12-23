#!/bin/sh

# If dependencies are needed grab them first


# Check if tailscale is installed already or not
if pacman -Qi tailscale &> /dev/null; then
  echo "tailscale is already installed"
else
  sudo pacman -S --noconfirm --needed tailscale
fi
