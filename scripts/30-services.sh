#!/bin/sh

# Enable sddm, networkmanager, etc
set -euo pipefail

echo "Enabling system services..."

sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now sddm.service

echo "Services enabled."