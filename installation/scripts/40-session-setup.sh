#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 40-session-setup.sh
# Apply dotfiles using GNU Stow OR copy locally (independent of repo)
#
# Modes:
#   - dev   : stow (symlink) from repo -> $HOME  (repo-dependent)
#   - local : copy from repo -> $HOME            (repo-independent)
#
# Assumes:
# - repo already cloned
# - stow is installed (dev mode)
# - rsync is installed (local mode)  [you already have it in helpers]
# - $HOME is available
# -----------------------------------------------------------------------------

###############################################################################
# CONFIG / PATHS
###############################################################################
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Arch-config/dotfiles}"

STOW_PACKAGES=(
  hypr
  swww
  kitty
  waybar
  swaync
)

REAL_CONFIG_ROOTS=(
  "$HOME/.config/waybar"
  "$HOME/.config/swaync"
)

# Default mode if not interactive:
DEFAULT_MODE="${DEFAULT_MODE:-dev}"   # dev | local

# Local install overwrite behavior:
#   0 = never overwrite existing files (safe default)
#   1 = overwrite existing files
LOCAL_OVERWRITE="${LOCAL_OVERWRITE:-0}"

###############################################################################
# HELPERS
###############################################################################
die() { echo "40-session-setup: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

prompt_mode() {
  local mode="${1:-}"

  # If MODE is set, respect it (no prompt)
  if [ -n "${MODE:-}" ]; then
    echo "$MODE"
    return 0
  fi

  # Non-interactive: use DEFAULT_MODE
  if [ ! -t 0 ]; then
    echo "$DEFAULT_MODE"
    return 0
  fi

  echo
  echo "Select dotfiles install mode:"
  echo "  1) dev   - symlink from repo using stow (recommended for development)"
  echo "  2) local - copy into ~/.config (independent of repo)"
  echo
  read -r -p "Choose [1/2] (default: 1): " ans || true
  ans="${ans:-1}"

  case "$ans" in
    1) mode="dev" ;;
    2) mode="local" ;;
    dev|DEV) mode="dev" ;;
    local|LOCAL) mode="local" ;;
    *) mode="dev" ;;
  esac

  echo "$mode"
}

ensure_real_roots() {
  echo "Ensuring local (real) config roots exist:"
  local dir
  for dir in "${REAL_CONFIG_ROOTS[@]}"; do
    echo "  - $dir"
    mkdir -p "$dir"
  done
}

###############################################################################
# DEV MODE (stow)
###############################################################################
apply_dev_install() {
  have_cmd stow || die "stow not found (needed for dev install)"
  cd "$DOTFILES_DIR"

  echo
  echo "Applying dotfiles with stow (dev install):"
  local pkg
  for pkg in "${STOW_PACKAGES[@]}"; do
    echo "  - $pkg"
  done

  stow -t "$HOME" "${STOW_PACKAGES[@]}"
  echo "Dev install complete (symlinks into repo)."
}

###############################################################################
# LOCAL MODE (copy)
###############################################################################
apply_local_install() {
  have_cmd rsync || die "rsync not found (needed for local install)"

  echo
  echo "Applying dotfiles by copying (local install):"
  echo "  Source: $DOTFILES_DIR"
  echo "  Target: $HOME"
  echo

  if [ "$LOCAL_OVERWRITE" -ne 1 ] && [ -t 0 ]; then
    read -r -p "Do you want to overwrite existing files? [y/N]: " ow || true
    case "${ow:-N}" in
      y|Y|yes|YES) LOCAL_OVERWRITE=1 ;;
      *) LOCAL_OVERWRITE=0 ;;
    esac
  fi

  local rsync_flags=(-a --no-perms --no-owner --no-group)
  if [ "$LOCAL_OVERWRITE" -eq 1 ]; then
    rsync_flags+=(--delete)   # makes target match source more closely
    echo "  Overwrite: YES (will replace existing files; may delete extras under target paths)"
  else
    rsync_flags+=(--ignore-existing)
    echo "  Overwrite: NO (will not replace existing files)"
  fi

  # Each package is a folder that contains paths like .config/...
  local pkg src
  for pkg in "${STOW_PACKAGES[@]}"; do
    src="$DOTFILES_DIR/$pkg/"
    [ -d "$src" ] || { echo "  - skipping missing package dir: $pkg"; continue; }

    echo "  - copying: $pkg"
    rsync "${rsync_flags[@]}" "$src" "$HOME/"
  done

  echo "Local install complete (files copied into ~/.config, independent of repo)."
}

###############################################################################
# MAIN
###############################################################################
main() {
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    echo "Dotfiles directory not found: $DOTFILES_DIR"
    echo "Skipping stow/copy step."
    exit 0
  fi

  ensure_real_roots

  local mode
  mode="$(prompt_mode)"

  case "$mode" in
    dev)   apply_dev_install ;;
    local) apply_local_install ;;
    *)     die "unknown mode: $mode (expected dev|local)" ;;
  esac

  echo "Done."
}

main "$@"
