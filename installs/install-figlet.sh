#!/bin/sh

# If dependencies are needed grab them first


# Check if figlet is installed already or not
if pacman -Qi figlet &> /dev/null; then
  echo "figlet is already installed"
else
  sudo pacman -S --noconfirm --needed figlet
fi
