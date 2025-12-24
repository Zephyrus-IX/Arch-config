#!/bin/sh

# If dependencies are needed grab them first
echo "Ensuring dependencies are met..."

if pacman -Qi glibc &> /dev/null; then
  echo "glibc is already installed"
else
  sudo pacman -S --noconfirm --needed glibc
fi

if pacman -Qi yyjson &> /dev/null; then
  echo "yyjson is already installed"
else
  sudo pacman -S --noconfirm --needed yyjson
fi


# Check if fastfetch is installed already or not
if pacman -Qi fastfetch &> /dev/null; then
  echo "fastfetch is already installed"
else
  sudo pacman -S --noconfirm --needed fastfetch
fi
