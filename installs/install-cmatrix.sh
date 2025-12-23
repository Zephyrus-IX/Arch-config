#!/bin/sh

# If dependencies are needed grab them first


# Check if cmatrix is installed already or not
if pacman -Qi cmatrix &> /dev/null; then
  echo "Cmatrix is already installed"
else
  sudo pacman -S --noconfirm --needed cmatrix
fi
