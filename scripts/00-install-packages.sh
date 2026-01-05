#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 00-install-packages.sh
# Goal:
# - Keep the exclusion list UI working (simple, reliable reads)
# - Let pacman/yay print normally (no output capture / no PTY / no indentation)
###############################################################################

###############################################################################
# USER CONFIG (inherited from environment if set)
###############################################################################
VERBOSE="${VERBOSE:-1}"              # kept for compatibility (not heavily used here)
EXCLUDE_PACKAGES="${EXCLUDE_PACKAGES:-$'\n'}"
SUDO_KEEPALIVE="${SUDO_KEEPALIVE:-1}"
INTERACTIVE="${INTERACTIVE:-1}"
BOOTSTRAP_YAY="${BOOTSTRAP_YAY:-1}"

# repo root and package dir
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${PKG_DIR:-$ROOT_DIR/installs}"

###############################################################################
# PRETTY OUTPUT (kept consistent)
###############################################################################
if [ -t 1 ]; then
  RED="$(printf '\033[0;31m')"
  GREEN="$(printf '\033[0;32m')"
  YELLOW="$(printf '\033[0;33m')"
  BLUE="$(printf '\033[0;34m')"
  CYAN="$(printf '\033[0;36m')"
  BOLD="$(printf '\033[1m')"
  DIM="$(printf '\033[2m')"
  RESET="$(printf '\033[0m')"
else
  RED= GREEN= YELLOW= BLUE= CYAN= BOLD= DIM= RESET=
fi

OK="${GREEN}✔${RESET}"
ERR="${RED}✖${RESET}"
SKIP="${YELLOW}↷${RESET}"
RUN="${CYAN}▶${RESET}"

###############################################################################
# SUDO WARM-UP
###############################################################################
sudo -v
if [ "$SUDO_KEEPALIVE" -eq 1 ]; then
  ( while :; do sudo -n -v 2>/dev/null; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT INT TERM
fi

###############################################################################
# TIER ORDER
###############################################################################
TIERS=(
  "base:${PKG_DIR}/base.packages"
  "helpers:${PKG_DIR}/helpers.packages"
  "core:${PKG_DIR}/core.packages"
  "services:${PKG_DIR}/services.packages"
  "apps:${PKG_DIR}/apps.packages"
  "cosmetic:${PKG_DIR}/cosmetic.packages"
)

###############################################################################
# PACKAGE FILE PARSING
# - strips blank lines
# - strips full-line comments
# - strips inline comments (# ...)
###############################################################################
read_packages_file() {
  local file="$1"
  mapfile -t packages < <(
    sed 's/#.*//' "$file" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | awk 'NF'
  )
  printf '%s\0' "${packages[@]}"
}

###############################################################################
# EXCLUDE SET (global)
###############################################################################
declare -A EXCL=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [ -z "$line" ] && continue
  EXCL["$line"]=1
done <<< "$EXCLUDE_PACKAGES"

###############################################################################
# FAST repo/AUR classification cache
###############################################################################
declare -A REPOPKG=()

build_repo_cache() {
  echo "${CYAN}${BOLD}Master package install${RESET} (${PKG_DIR})"
  echo "${RUN} Caching repo package list (pacman -Slq)"
  while IFS= read -r p; do
    [ -n "$p" ] && REPOPKG["$p"]=1
  done < <(pacman -Slq)
  echo "${OK} Repo package cache ready"
}

is_repo_pkg() {
  local p="$1"
  [[ -n "${REPOPKG[$p]+x}" ]]
}

###############################################################################
# INTERACTIVE EXCLUSION UI (KNOWN-GOOD SIMPLE VERSION)
###############################################################################
interactive_exclude_tier() {
  local tier="$1"; shift
  local -a pkgs=("$@")

  if [ "${#pkgs[@]}" -eq 0 ]; then
    echo
    printf "%s [%s] No packages found.\n" "$SKIP" "$tier"
    printf '%s\0' "${pkgs[@]}"
    return 0
  fi

  echo
  printf "%s%s[%s] Packages%s\n" "$BOLD" "$CYAN" "$tier" "$RESET"
  local i=1
  for p in "${pkgs[@]}"; do
    printf "  %2d) %s\n" "$i" "$p"
    i=$((i+1))
  done

  if [ "$INTERACTIVE" -ne 1 ]; then
    printf '%s\0' "${pkgs[@]}"
    return 0
  fi

  echo
  printf "Select packages to EXCLUDE for [%s] (e.g. '1 3 7-9'), or press Enter to install all: " "$tier"
  local sel=""
  IFS= read -r sel || true
  sel="${sel:-}"

  if [ -z "$sel" ]; then
    printf '%s\0' "${pkgs[@]}"
    return 0
  fi

  declare -A drop_idx=()
  local tok
  for tok in $sel; do
    if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      local a="${BASH_REMATCH[1]}"
      local b="${BASH_REMATCH[2]}"
      if (( a > b )); then local tmp="$a"; a="$b"; b="$tmp"; fi
      for ((j=a; j<=b; j++)); do drop_idx["$j"]=1; done
    elif [[ "$tok" =~ ^[0-9]+$ ]]; then
      drop_idx["$tok"]=1
    fi
  done

  local -a out=()
  for ((j=1; j<=${#pkgs[@]}; j++)); do
    if [[ -n "${drop_idx[$j]+x}" ]]; then
      continue
    fi
    out+=("${pkgs[$((j-1))]}")
  done

  echo
  printf "%s [%s] Will install: %d packages\n" "$OK" "$tier" "${#out[@]}"
  printf '%s\0' "${out[@]}"
}

###############################################################################
# yay helpers
###############################################################################
have_cmd() { command -v "$1" >/dev/null 2>&1; }

yay_user() {
  if [ -n "${SUDO_USER:-}" ]; then
    printf "%s" "$SUDO_USER"
  else
    printf "%s" "$(id -un)"
  fi
}

ensure_yay() {
  [ "$BOOTSTRAP_YAY" -eq 1 ] || return 1
  have_cmd yay && return 0

  echo "${RUN} Bootstrapping yay (needs git + base-devel)"
  sudo pacman -S --noconfirm --needed git base-devel

  local u tmpdir
  u="$(yay_user)"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir" 2>/dev/null || true' RETURN

  su - "$u" -c "
    set -e
    cd '$tmpdir'
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
}

###############################################################################
# Install functions (SIMPLE: PRINT DIRECTLY)
###############################################################################
install_repo_pkgs() {
  local -a pkgs=("$@")
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  sudo pacman -S --noconfirm --needed "${pkgs[@]}"
}

install_aur_pkgs() {
  local -a pkgs=("$@")
  [ "${#pkgs[@]}" -eq 0 ] && return 0

  if ! have_cmd yay; then
    # If yay itself is requested, bootstrap it
    local needs_yay=0 p
    for p in "${pkgs[@]}"; do
      [ "$p" = "yay" ] && needs_yay=1 && break
    done
    if [ "$needs_yay" -eq 1 ]; then
      ensure_yay
      local -a rest=()
      for p in "${pkgs[@]}"; do
        [ "$p" = "yay" ] && continue
        rest+=("$p")
      done
      pkgs=("${rest[@]}")
      [ "${#pkgs[@]}" -eq 0 ] && return 0
    else
      echo "${ERR} AUR packages requested but 'yay' is not installed."
      echo "Put 'yay' in helpers tier or set BOOTSTRAP_YAY=1."
      return 1
    fi
  fi

  local yay_flags=(--noconfirm --needed --answerclean None --answerdiff None)
  local u
  u="$(yay_user)"

  if [ "$(id -u)" -eq 0 ]; then
    su - "$u" -c "yay ${yay_flags[*]} -S ${pkgs[*]}"
  else
    yay "${yay_flags[@]}" -S "${pkgs[@]}"
  fi
}

###############################################################################
# INSTALLER (per-tier)
###############################################################################
install_tier() {
  local tier="$1"
  local file="$2"

  if [ ! -f "$file" ]; then
    printf "%s [%s] Missing file: %s\n" "$SKIP" "$tier" "$file"
    return 0
  fi

  local -a pkgs=()
  while IFS= read -r -d '' p; do
    [ -n "${p:-}" ] && pkgs+=("$p")
  done < <(read_packages_file "$file")

  # Apply global excludes
  local -a filtered=()
  local p
  for p in "${pkgs[@]}"; do
    [[ -n "${EXCL[$p]+x}" ]] && continue
    filtered+=("$p")
  done

  # Ask exclusions for THIS tier
  local -a chosen=()
  while IFS= read -r -d '' p; do
    [ -n "${p:-}" ] && chosen+=("$p")
  done < <(interactive_exclude_tier "$tier" "${filtered[@]}")

  # Any package in filtered but not in chosen becomes excluded globally
  declare -A keep=()
  for p in "${chosen[@]}"; do keep["$p"]=1; done
  for p in "${filtered[@]}"; do
    if [[ -z "${keep[$p]+x}" ]]; then
      EXCL["$p"]=1
    fi
  done

  if [ "${#chosen[@]}" -eq 0 ]; then
    printf "%s [%s] Nothing selected to install.\n" "$SKIP" "$tier"
    return 0
  fi

  echo
  printf "%s Install [%s] now? [Y/n] " "$BOLD" "$tier"
  local ans=""
  IFS= read -r ans || true
  ans="${ans:-Y}"
  case "$ans" in
    Y|y|yes|YES) ;;
    *) printf "%s [%s] Skipped by user.\n" "$SKIP" "$tier"; return 0 ;;
  esac

  # Split into repo vs AUR
  local -a repo_pkgs=()
  local -a aur_pkgs=()
  for p in "${chosen[@]}"; do
    if is_repo_pkg "$p"; then
      repo_pkgs+=("$p")
    else
      aur_pkgs+=("$p")
    fi
  done

  echo
  printf "%s [%s] Repo: %d | AUR: %d\n" "$OK" "$tier" "${#repo_pkgs[@]}" "${#aur_pkgs[@]}"

  # Install (prints normally)
  install_repo_pkgs "${repo_pkgs[@]}"
  install_aur_pkgs  "${aur_pkgs[@]}"

  printf "%s Installed [%s]\n" "$OK" "$tier"
}

###############################################################################
# MAIN
###############################################################################
build_repo_cache

RAN=0
FAILED=0

for entry in "${TIERS[@]}"; do
  tier="${entry%%:*}"
  file="${entry#*:}"

  if install_tier "$tier" "$file"; then
    RAN=$((RAN + 1))
  else
    FAILED=$((FAILED + 1))
    echo
    echo "${ERR} Stopping due to failure."
    break
  fi
done

echo
printf "%sSUMMARY%s\n" "$BOLD" "$RESET"
printf "  %s tiers completed: %s\n" "$OK" "$RAN"
printf "  %s tiers failed:    %s\n" "$ERR" "$FAILED"

[ "$FAILED" -eq 0 ]
