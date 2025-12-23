#!/bin/sh

# If dependencies are needed grab them first


# Check if openssh is installed already or not
if pacman -Qi openssh &> /dev/null; then
  echo "open-ssh is already installed"
else
  pacman -S --noconfirm --needed openssh
fi
