#!/usr/bin/env bash
set -euo pipefail

echo "Enabling system services..."
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now sddm.service
echo "Services enabled."

TARGET_USER="${SUDO_USER:-$(id -un)}"

echo "Enabling PipeWire user services for: $TARGET_USER"

# Ensures user services can run without an active login session (one-shot reliability)
sudo loginctl enable-linger "$TARGET_USER" || true

# Enable under the *user* systemd, not root's
su - "$TARGET_USER" -c 'systemctl --user enable --now pipewire pipewire-pulse wireplumber'
echo "PipeWire user services enabled."
