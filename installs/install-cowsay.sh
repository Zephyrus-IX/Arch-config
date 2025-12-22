#!/bin/sh

# If dependencies are needed grab them first


# Check if cowsay is installed already or not
if pacman -Qi stow &> /dev/null; then
  echo "Stow is already installed"
else
  yay -S --noconfirm --needed stow
fi
