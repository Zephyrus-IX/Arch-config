#!/bin/sh

# Enable sddm, networkmanager, etc
set -euo pipefail

echo "Enabling system services..."

sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now sddm.service

echo "Services enabled."


# Enable audio services
echo "Enabling Pipewire (global user services)..."

sudo systemctl --global enable pipewire.service
sudo systemctl --global enable pipewire-pulse.service
sudo systemctl --global enable wireplumber.service

echo "Pipewire global user services enabled."