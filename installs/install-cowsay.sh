#!/bin/sh

# If dependencies are needed grab them first


# Check if cowsay is installed already or not
if pacman -Qi cowsay &> /dev/null; then
  echo "cowsay is already installed"
else
  yay -S --noconfirm --needed cowsay
fi
