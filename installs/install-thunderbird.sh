#!/bin/sh

# If dependencies are needed grab them first


# Check if thunderbird is already installed
if pacman -Qi thunderbird &> /dev/null; then
  echo "thunderbird is already installed"
else
  sudo pacman -S --noconfirm --needed thunderbird
fi
