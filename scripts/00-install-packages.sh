#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 00-install-packages.sh
# Fix: print the exclusion UI to STDERR to avoid buffering when stdout is piped.
###############################################################################

VERBOSE="${VERBOSE:-1}"
EXCLUDE_PACKAGES="${EXCLUDE_PACKAGES:-$'\n'}"
SUDO_KEEPALIVE="${SUDO_KEEPALIVE:-1}"
INTERACTIVE="${INTERACTIVE:-1}"
BOOTSTRAP_YAY="${BOOTSTRAP_YAY:-1}"

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

# UI helper (prints immediately even when stdout is piped)
ui() { printf "%b" "$*" >&2; }
uiln() { printf "%b\n" "$*" >&2; }

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
# TIER ORDER (auto-discover from installs/*.packages)
#
# Expected naming:
#   NN-name.packages   (e.g. 00-base.packages, 10-helpers.packages, ...)
#
# Tier label rules:
#   - Uses filename after numeric prefix and dash: "00-base.packages" -> "base"
#   - If a file doesn't match NN-name.packages, it's ignored (so stray files won't break installs)
###############################################################################
discover_tiers() {
  local dir="$1"
  local -a files=()

  # Collect and sort package files
  while IFS= read -r f; do
    files+=("$f")
  done < <(find "$dir" -maxdepth 1 -type f -name '*.packages' | sort)

  local -a tiers=()
  local base name tier
  for f in "${files[@]}"; do
    base="$(basename "$f")"

    # Only accept NN-name.packages
    if [[ "$base" =~ ^([0-9]+)-(.+)\.packages$ ]]; then
      name="${BASH_REMATCH[2]}"
      tier="$name"
      tiers+=("${tier}:${f}")
    fi
  done

  printf '%s\0' "${tiers[@]}"
}

TIERS=()
while IFS= read -r -d '' entry; do
  TIERS+=("$entry")
done < <(discover_tiers "$PKG_DIR")

if [ "${#TIERS[@]}" -eq 0 ]; then
  uiln "${SKIP} No tier files found in: $PKG_DIR"
  uiln "${DIM}Expected: NN-name.packages (e.g. 00-base.packages)${RESET}"
  exit 0
fi

###############################################################################
# PACKAGE FILE PARSING
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
  uiln "${CYAN}${BOLD}Master package install${RESET} (${PKG_DIR})"
  uiln "${RUN} Caching repo package list (pacman -Slq)"
  while IFS= read -r p; do
    [ -n "$p" ] && REPOPKG["$p"]=1
  done < <(pacman -Slq)
  uiln "${OK} Repo package cache ready"
}

is_repo_pkg() {
  local p="$1"
  [[ -n "${REPOPKG[$p]+x}" ]]
}

###############################################################################
# INTERACTIVE EXCLUSION UI (prints to STDERR; outputs selections on STDOUT)
###############################################################################
interactive_exclude_tier() {
  local tier="$1"; shift
  local -a pkgs=("$@")

  if [ "${#pkgs[@]}" -eq 0 ]; then
    uiln ""
    uiln "${SKIP} [${tier}] No packages found."
    printf '%s\0' "${pkgs[@]}"
    return 0
  fi

  uiln ""
  uiln "${BOLD}${CYAN}[${tier}] Packages${RESET}"
  local i=1
  local p
  for p in "${pkgs[@]}"; do
    uiln "  $(printf '%2d' "$i")) $p"
    i=$((i+1))
  done

  if [ "$INTERACTIVE" -ne 1 ]; then
    printf '%s\0' "${pkgs[@]}"
    return 0
  fi

  uiln ""
  ui "Select packages to EXCLUDE for [${tier}] (e.g. '1 3 7-9'), or press Enter to install all: "
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

  uiln ""
  uiln "${OK} [${tier}] Will install: ${#out[@]} packages"

  # IMPORTANT: selections go to STDOUT for the caller to read -d ''
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

  # Preinstall everything yay build needs so makepkg never tries sudo for deps
  sudo pacman -S --noconfirm --needed git base-devel go >/dev/null 2>&1 || true

  local u tmpdir
  u="$(yay_user)"
  tmpdir=""
  tmpdir="$(mktemp -d)"

  # Only clean up if tmpdir is set
  trap '[ -n "${tmpdir:-}" ] && rm -rf "$tmpdir" 2>/dev/null || true' RETURN

  # Build as normal user (no sudo needed now)
  su - "$u" -c "
    set -e
    cd '$tmpdir'
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -s --noconfirm
  "

  # Install the built package as root (no sudo prompts inside makepkg)
  local pkg
  pkg="$(ls -1 "$tmpdir"/yay/yay-*.pkg.tar.* | head -n 1)"
  sudo pacman -U --noconfirm --needed "$pkg"
}


###############################################################################
# Install functions (prints normally)
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
      uiln "${ERR} AUR packages requested but 'yay' is not installed."
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
    uiln "${SKIP} [${tier}] Missing file: $file"
    return 0
  fi

  local -a pkgs=()
  while IFS= read -r -d '' p; do
    [ -n "${p:-}" ] && pkgs+=("$p")
  done < <(read_packages_file "$file")

  local -a filtered=()
  local p
  for p in "${pkgs[@]}"; do
    [[ -n "${EXCL[$p]+x}" ]] && continue
    filtered+=("$p")
  done

  local -a chosen=()
  while IFS= read -r -d '' p; do
    [ -n "${p:-}" ] && chosen+=("$p")
  done < <(interactive_exclude_tier "$tier" "${filtered[@]}")

  declare -A keep=()
  for p in "${chosen[@]}"; do keep["$p"]=1; done
  for p in "${filtered[@]}"; do
    if [[ -z "${keep[$p]+x}" ]]; then
      EXCL["$p"]=1
    fi
  done

  if [ "${#chosen[@]}" -eq 0 ]; then
    uiln "${SKIP} [${tier}] Nothing selected to install."
    return 0
  fi

  uiln ""
  ui "${BOLD}Install [${tier}] now?${RESET} [Y/n] "
  local ans=""
  IFS= read -r ans || true
  ans="${ans:-Y}"
  case "$ans" in
    Y|y|yes|YES) ;;
    *) uiln "${SKIP} [${tier}] Skipped by user."; return 0 ;;
  esac

  local -a repo_pkgs=()
  local -a aur_pkgs=()
  for p in "${chosen[@]}"; do
    if is_repo_pkg "$p"; then repo_pkgs+=("$p"); else aur_pkgs+=("$p"); fi
  done

  uiln ""
  uiln "${OK} [${tier}] Repo: ${#repo_pkgs[@]} | AUR: ${#aur_pkgs[@]}"

  install_repo_pkgs "${repo_pkgs[@]}"
  install_aur_pkgs  "${aur_pkgs[@]}"

  uiln "${OK} Installed [${tier}]"
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
    uiln ""
    uiln "${ERR} Stopping due to failure."
    break
  fi
done

uiln ""
uiln "${BOLD}SUMMARY${RESET}"
uiln "  ${OK} tiers completed: ${RAN}"
uiln "  ${ERR} tiers failed:    ${FAILED}"

[ "$FAILED" -eq 0 ]
