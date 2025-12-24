#!/bin/sh

# If dependencies are needed grab them first
echo "Ensuring dependencies are met..."

if sudo pacman -Qi bash &> /dev/null; then
  echo "bash is already installed"
else
  sudo pacman -S --noconfirm --needed bash
fi

if sudo pacman -Qi electron36 &> /dev/null; then
  echo "electron36 is already installed"
else
  sudo pacman -S --noconfirm --needed electron36
fi

if sudo pacman -Qi hicolor-icon-theme &> /dev/null; then
  echo "hicolor-icon-theme is already installed"
else
  sudo pacman -S --noconfirm --needed hicolor-icon-theme
fi

if sudo pacman -Qi xdg-utils &> /dev/null; then
  echo "xdg-utils is already installed"
else
  sudo pacman -S --noconfirm --needed xdg-utils
fi

# Check if proton-mail-bin is already installed
if pacman -Qi proton-mail-bin &> /dev/null; then
  echo "proton-mail-bin is already installed"
else
  yay -S --noconfirm --needed proton-mail-bin
fi

# ---- Proton Mail Wayland/Electron crash check + auto-fix (ONLY if needed) ----
# This installs a user desktop override that forces X11 (XWayland) if Proton Mail
# crashes (segfault) on launch under Wayland. If no crash is detected, it does nothing.

if command -v proton-mail >/dev/null 2>&1; then
  # Don't touch anything if the user already has an override
  if [ -f "$HOME/.local/share/applications/proton-mail.desktop" ]; then
    echo "Proton Mail launcher override already exists; skipping workaround."
  else
    echo "Checking Proton Mail launch behavior (Wayland crash check)..."

    LOG="$(mktemp)"

    # Attempt a short launch; if it segfaults quickly we detect it.
    timeout 5s proton-mail >/dev/null 2>"$LOG"
    rc=$?

    if grep -qiE "segmentation fault|sigsegv|core dumped" "$LOG" || [ "$rc" -ne 0 -a "$rc" -ne 124 ]; then
      echo "Detected Proton Mail crash pattern. Applying launcher workaround (force X11 + disable GPU)..."

      mkdir -p "$HOME/.local/share/applications"

      if [ -f /usr/share/applications/proton-mail.desktop ]; then
        cp /usr/share/applications/proton-mail.desktop "$HOME/.local/share/applications/proton-mail.desktop"
      else
        cat > "$HOME/.local/share/applications/proton-mail.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Proton Mail
Exec=proton-mail
Terminal=false
Categories=Network;Email;
EOF
      fi

      # First try the safer workaround WITHOUT --no-sandbox
      SAFE_EXEC='env XDG_SESSION_TYPE=x11 proton-mail --disable-gpu --disable-features=UseOzonePlatform --ozone-platform=x11'
      timeout 5s sh -lc "$SAFE_EXEC" >/dev/null 2>"$LOG"
      rc2=$?

      # If it still crashes, fall back to the exact command that you confirmed works
      if grep -qiE "segmentation fault|sigsegv|core dumped" "$LOG" || [ "$rc2" -ne 0 -a "$rc2" -ne 124 ]; then
        SAFE_EXEC='env -u WAYLAND_DISPLAY XDG_SESSION_TYPE=x11 proton-mail --disable-gpu --no-sandbox --disable-features=UseOzonePlatform --ozone-platform=x11'
      fi

      # Update Exec line in the user override desktop file
      sed -i "s|^Exec=.*|Exec=$SAFE_EXEC|" "$HOME/.local/share/applications/proton-mail.desktop"

      # Refresh desktop database (ignore errors if tool isn't present)
      update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

      echo "Workaround installed: ~/.local/share/applications/proton-mail.desktop"
    else
      echo "No Proton Mail crash detected; no workaround needed."
    fi

    rm -f "$LOG"
  fi
fi

