#!/usr/bin/env bash
set -euo pipefail

echo "Enabling system services..."
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now sddm.service
sudo systemctl enable --now bluetooth.service
sudo systemctl start tailscaled
echo "Services enabled."

TARGET_USER="${SUDO_USER:-$(id -un)}"
TARGET_UID="$(id -u "$TARGET_USER")"

echo "Installing PipeWire audio stack (if missing)..."
sudo pacman -S --needed --noconfirm pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber

echo "Enabling PipeWire user services for: $TARGET_USER"

# Allow user services to run without an active login session
sudo loginctl enable-linger "$TARGET_USER" || true

# Ensure the user systemd instance exists + target runtime dir is correct
sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
  systemctl --user daemon-reload || true

sudo -u "$TARGET_USER" XDG_RUNTIME_DIR="/run/user/${TARGET_UID}" \
  systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

echo "PipeWire user services enabled."
