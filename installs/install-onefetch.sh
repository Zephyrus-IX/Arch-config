#!/bin/sh

# If dependencies are needed grab them first


# Check if onefetch is installed already or not
if pacman -Qi onefetch &> /dev/null; then
  echo "onefetch is already installed"
else
  sudo pacman -S --noconfirm --needed onefetch
fi
