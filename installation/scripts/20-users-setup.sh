#!/bin/sh
set -eu

TARGET_USER="${SUDO_USER:-$(id -un)}"

[ -x /bin/zsh ] || { echo "20-users-setup: zsh not found at /bin/zsh" >&2; exit 1; }

chsh -s /bin/zsh "$TARGET_USER"
getent passwd "$TARGET_USER" | cut -d: -f7
