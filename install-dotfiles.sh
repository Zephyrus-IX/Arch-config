#!/bin/sh

# Script env vars
ORIGINAL_DIR = $(pwd)
REPO_URL = "https://github.com/<my repo>/dotfiles" # NEED TO CREATE
REPO_NAME = "dotfiles"


# Helper function
is_stow_installed() {
    pacman -Qi "stow" &> /dev/null
}


# Confirm stow is installed
if ! is_stow_installed; then
    echo "Install Stow first!"
    exit 1
fi


# Change to root dir
cd ~


# Check if the repository already exists
if [ -d "$REPO_NAME" ]; then
    echo "Repository '$REPO_NAME' already exists. Skipping clone."
else
    git clone "$REPO_URL"
fi


# Check if the clone was successful
if [ $? -eq 0 ]; then
    echo "Removing old configs"
    # Do any removal of old configs here before sourcing repo configs with stow below

    # cd to the repo clone and run stow
    stow <something>

else 
    echo "Failed to clone the repository"
    exit 1
fi