#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 40-session-setup.sh
#
# Modes:
#   dev   : stow dotfiles into $HOME (repo-dependent)   [FORCE deletes conflicts]
#   local : copy dotfiles into $HOME (repo-independent)
#
# Designed to work when called by install-setup.sh:
# - reads prompts from /dev/tty
# - prints prompts to STDERR
###############################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$ROOT_DIR/dotfiles}"

DEFAULT_MODE="${DEFAULT_MODE:-dev}"      # dev | local
LOCAL_OVERWRITE="${LOCAL_OVERWRITE:-0}" # only for local mode
FORCE_DELETE_CONFLICTS="${FORCE_DELETE_CONFLICTS:-1}" # dev mode: 1 = option B

TTY="/dev/tty"

ui()   { printf "%b" "$*" >&2; }
uiln() { printf "%b\n" "$*" >&2; }

die() { uiln "40-session-setup: $*"; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }

read_tty() {
  local __outvar="${1:?outvar required}"
  local prompt="${2:-}"
  local ans=""
  [ -n "$prompt" ] && ui "$prompt"
  if [ -e "$TTY" ]; then
    IFS= read -r ans < "$TTY" || true
  else
    IFS= read -r ans || true
  fi
  printf -v "$__outvar" '%s' "$ans"
}

list_packages() {
  find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

pick_mode() {
  if [ -n "${MODE:-}" ]; then
    echo "${MODE,,}"
    return 0
  fi

  if [ ! -t 0 ] && [ ! -e "$TTY" ]; then
    echo "$DEFAULT_MODE"
    return 0
  fi

  uiln ""
  uiln "Dotfiles install mode:"
  uiln ""
  uiln "  1) DEV   (symlink via stow; repo-dependent)"
  uiln "     - ~/.config points into the repo"
  uiln "     - GOOD for committing changes"
  uiln ""
  uiln "  2) LOCAL (copy into ~/.config; repo-independent)"
  uiln "     - real files/dirs in ~/.config"
  uiln "     - GOOD for set-and-forget installs"
  uiln ""

  local ans=""
  read_tty ans "Choose [1/2] or type [dev/local] (default: 1): "
  ans="${ans:-1}"; ans="${ans,,}"

  case "$ans" in
    1|dev) echo "dev" ;;
    2|local) echo "local" ;;
    *) echo "dev" ;;
  esac
}

# Safety: only allow deleting relative paths inside $HOME
safe_rm_home() {
  local rel="${1:?relative path required}"

  # disallow empties / weird paths
  [ -n "$rel" ] || return 0
  [[ "$rel" != /* ]] || die "refusing to delete absolute path: $rel"
  [[ "$rel" != *".."* ]] || die "refusing to delete path containing '..': $rel"
  [[ "$rel" != "." && "$rel" != "./" ]] || die "refusing to delete unsafe path: $rel"

  local target="$HOME/$rel"
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf -- "$target"
  fi
}

# Parse stow dry-run output for:
# - LINK: <target> => ...
# - conflicts that mention: existing target <target> ...
collect_targets_to_delete() {
  local pkg="${1:?pkg required}"
  local out

  # run inside dotfiles dir so stow output is consistent
  out="$(stow -n -v -t "$HOME" "$pkg" 2>&1 || true)"

  # 1) Targets stow intends to create links at (handles full-dir links like .config/rofi)
  #    LINK: .config/rofi => ...
  printf "%s\n" "$out" | awk '
    /^LINK: / {
      sub(/^LINK: /, "", $0)
      split($0, a, / => /)
      print a[1]
    }
  '

  # 2) Targets that are explicitly called out as conflicts:
  #    ... existing target .config/hypr/hyprland.conf ...
  printf "%s\n" "$out" | awk '
    /existing target / {
      for (i=1; i<=NF; i++) {
        if ($i == "target") {
          print $(i+1)
          break
        }
      }
    }
  '
}

dev_install() {
  have_cmd stow || die "stow not found"
  [ -d "$DOTFILES_DIR" ] || die "dotfiles directory not found: $DOTFILES_DIR"

  mapfile -t pkgs < <(list_packages)
  [ "${#pkgs[@]}" -gt 0 ] || die "no dotfiles packages found in: $DOTFILES_DIR"

  uiln ""
  uiln "Dev install: stowing dotfiles into \$HOME (symlinks)"
  uiln "  dotfiles: $DOTFILES_DIR"
  uiln "  packages:"
  printf "    - %s\n" "${pkgs[@]}" >&2

  cd "$DOTFILES_DIR"

  if [ "$FORCE_DELETE_CONFLICTS" -eq 1 ]; then
    uiln ""
    uiln "Dev install policy: FORCE DELETE conflicts (Option B)"
    uiln "  - Any existing target that blocks stow will be removed."
    uiln "  - This includes dirs like ~/.config/rofi if the package links that dir."
  fi

  local pkg
  for pkg in "${pkgs[@]}"; do
    uiln ""
    uiln "==> [$pkg] preparing..."

    if [ "$FORCE_DELETE_CONFLICTS" -eq 1 ]; then
      # De-dupe targets to delete
      declare -A seen=()
      while IFS= read -r rel; do
        rel="${rel//$'\r'/}"
        rel="$(printf "%s" "$rel" | xargs || true)"
        [ -n "$rel" ] || continue
        seen["$rel"]=1
      done < <(collect_targets_to_delete "$pkg")

      # Delete them
      for rel in "${!seen[@]}"; do
        # Only delete if it exists (rm is already safe)
        if [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; then
          uiln "  - removing: ~/$rel"
          safe_rm_home "$rel"
        fi
      done
    fi

    uiln "==> [$pkg] stowing..."
    stow -v -t "$HOME" "$pkg"
  done

  uiln ""
  uiln "Dev install complete."
}

local_install() {
  have_cmd rsync || die "rsync not found"
  [ -d "$DOTFILES_DIR" ] || die "dotfiles directory not found: $DOTFILES_DIR"

  mapfile -t pkgs < <(list_packages)
  [ "${#pkgs[@]}" -gt 0 ] || die "no dotfiles packages found in: $DOTFILES_DIR"

  uiln ""
  uiln "Local install: copying dotfiles into \$HOME (repo-independent)"
  uiln "  source: $DOTFILES_DIR"
  uiln "  target: $HOME"

  local rsync_flags=(-a --no-perms --no-owner --no-group)
  if [ "$LOCAL_OVERWRITE" -eq 1 ]; then
    rsync_flags+=(--delete)
    uiln "  overwrite: YES"
  else
    rsync_flags+=(--ignore-existing)
    uiln "  overwrite: NO"
  fi

  local pkg
  for pkg in "${pkgs[@]}"; do
    uiln "  - copying: $pkg"
    rsync "${rsync_flags[@]}" "$DOTFILES_DIR/$pkg/" "$HOME/"
  done

  uiln "Local install complete."
}

main() {
  [ -d "$DOTFILES_DIR" ] || die "dotfiles directory not found: $DOTFILES_DIR"

  local mode
  mode="$(pick_mode)"

  case "$mode" in
    dev)   dev_install ;;
    local) local_install ;;
    *)     die "unknown MODE: '$mode' (use dev|local)" ;;
  esac

  uiln "Done."
}

main "$@"

