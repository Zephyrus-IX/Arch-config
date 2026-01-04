#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# USER CONFIG (edit these)
###############################################################################

# Show installer output:
# 1 = always show output (default)
# 0 = only show output when a script fails
VERBOSE=1

# Exclude list by package name (one per line). Applies to all tiers.
EXCLUDE_PACKAGES="
"

# Keep sudo alive during run (prevents timeout mid-install)
# 1 = yes, 0 = no
SUDO_KEEPALIVE=1

# Prompt per tier to exclude packages interactively.
# 1 = yes, 0 = no prompts (installs everything, minus EXCLUDE_PACKAGES)
INTERACTIVE=1

# Where your tiered package files live
PKG_DIR="install/packaging"

# If yay is needed and not installed, auto-bootstrap it from AUR.
BOOTSTRAP_YAY=1

###############################################################################
# SUDO WARM-UP (run anywhere as any user, without becoming root)
###############################################################################
sudo -v

if [ "$SUDO_KEEPALIVE" -eq 1 ]; then
  ( while :; do sudo -n -v 2>/dev/null; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT INT TERM
fi

###############################################################################
# PRETTY OUTPUT (colors/icons)
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

# Indent installer output blocks (pipe in blue, text dimmed)
indent() { sed "s/^/${DIM}${BLUE}│${RESET}${DIM}    /"; }

###############################################################################
# SPINNER
###############################################################################
spinner_start() {
  SPIN_MSG=$1
  SPIN_CHARS='|/-\'
  SPIN_i=0
  printf '\033[?25l' 2>/dev/null || true

  (
    while :; do
      c=$(printf "%s" "$SPIN_CHARS" | cut -c $(( (SPIN_i % 4) + 1 )))
      SPIN_i=$((SPIN_i + 1))
      printf "\r%s %s %s%s%s" "$RUN" "$c" "$BOLD" "$SPIN_MSG" "$RESET"
      sleep 0.1
    done
  ) &
  SPIN_PID=$!
}

spinner_stop() {
  code=$1
  msg=$2

  kill "$SPIN_PID" 2>/dev/null || true
  wait "$SPIN_PID" 2>/dev/null || true

  printf "\r\033[K" 2>/dev/null || true
  printf '\033[?25h' 2>/dev/null || true

  if [ "$code" -eq 0 ]; then
    printf "%s %s\n" "$OK" "$msg"
  else
    printf "%s %s\n" "$ERR" "$msg"
  fi
}

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
###############################################################################
# - strips blank lines
# - strips full-line comments
# - strips inline comments (# ...)
# - trims whitespace
read_packages_file() {
  local file="$1"
  mapfile -t packages < <(
    sed 's/#.*//' "$file" \
      | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
      | awk 'NF'
  )
  printf '%s\0' "${packages[@]}"
}

# Build a set from EXCLUDE_PACKAGES lines
declare -A EXCL=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [ -z "$line" ] && continue
  EXCL["$line"]=1
done <<< "$EXCLUDE_PACKAGES"

filter_excluded() {
  local -a in=("$@")
  local -a out=()
  local p
  for p in "${in[@]}"; do
    if [[ -n "${EXCL[$p]+x}" ]]; then
      continue
    fi
    out+=("$p")
  done
  printf '%s\0' "${out[@]}"
}

###############################################################################
# INTERACTIVE EXCLUSION UI
###############################################################################
# Numeric selection:
#   1 2 5
#   1-4
# Empty input => no exclusions
interactive_exclude() {
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
    printf "\nPress Enter to continue (%d packages)..." "${#pkgs[@]}"
    read -r _ || true
    printf '%s\0' "${pkgs[@]}"
    return 0
  fi

  printf "\nSelect packages to EXCLUDE (e.g. '1 3 7-9'), or press Enter to install all: "
  read -r sel || true
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
      if (( a > b )); then
        local tmp="$a"; a="$b"; b="$tmp"
      fi
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
  if [ "${#out[@]}" -eq 0 ]; then
    printf "%s [%s] Nothing selected to install.\n" "$SKIP" "$tier"
  fi

  printf '%s\0' "${out[@]}"
}

###############################################################################
# PACMAN vs AUR (yay) INSTALL HELPERS
###############################################################################
have_cmd() { command -v "$1" >/dev/null 2>&1; }

yay_user() {
  if [ -n "${SUDO_USER:-}" ]; then
    printf "%s" "$SUDO_USER"
  else
    printf "%s" "$(id -un)"
  fi
}

# Pre-classify packages into official repo vs AUR
# Uses pacman -Si which returns 0 if package exists in sync DB.
classify_packages() {
  local -a in=("$@")
  local -a repo=()
  local -a aur=()
  local p

  for p in "${in[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then
      repo+=("$p")
    else
      aur+=("$p")
    fi
  done

  printf '%s\0' "${repo[@]}"
  printf '\n'
  printf '%s\0' "${aur[@]}"
}

install_repo_pkgs() {
  local -a pkgs=("$@")
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  sudo pacman -S --noconfirm --needed "${pkgs[@]}"
}

# Bootstrap yay from AUR (only when needed and enabled)
ensure_yay() {
  [ "$BOOTSTRAP_YAY" -eq 1 ] || return 1
  have_cmd yay && return 0

  # Need tools to build
  sudo pacman -S --noconfirm --needed git base-devel >/dev/null 2>&1 || true

  local u
  u="$(yay_user)"

  # Build yay in a temp dir as normal user
  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir" 2>/dev/null || true' RETURN

  # Use su to ensure it's not built as root
  su - "$u" -c "
    set -e
    cd '$tmpdir'
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
}

install_aur_pkgs() {
  local -a pkgs=("$@")
  [ "${#pkgs[@]}" -eq 0 ] && return 0

  # If yay isn't installed yet but AUR pkgs are requested,
  # try to bootstrap yay (especially if yay itself is in the list).
  if ! have_cmd yay; then
    local needs_yay=0
    local p
    for p in "${pkgs[@]}"; do
      if [ "$p" = "yay" ]; then
        needs_yay=1
        break
      fi
    done

    if [ "$needs_yay" -eq 1 ]; then
      ensure_yay || {
        echo "ERROR: Could not bootstrap yay."
        return 1
      }
      # Remove 'yay' from pkgs list now that it's installed
      local -a rest=()
      for p in "${pkgs[@]}"; do
        [ "$p" = "yay" ] && continue
        rest+=("$p")
      done
      pkgs=("${rest[@]}")
      [ "${#pkgs[@]}" -eq 0 ] && return 0
    else
      echo "ERROR: AUR packages requested but 'yay' is not installed yet."
      echo "Put 'yay' in an early tier (helpers) or enable BOOTSTRAP_YAY=1."
      return 1
    fi
  fi

  local u
  u="$(yay_user)"

  # Run yay as normal user
  if [ "$(id -u)" -eq 0 ]; then
    su - "$u" -c "yay -S --noconfirm --needed ${pkgs[*]}"
  else
    yay -S --noconfirm --needed "${pkgs[@]}"
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
  while IFS= read -r -d '' p; do pkgs+=("$p"); done < <(read_packages_file "$file")

  local -a pkgs2=()
  while IFS= read -r -d '' p; do pkgs2+=("$p"); done < <(filter_excluded "${pkgs[@]}")

  local -a final=()
  while IFS= read -r -d '' p; do final+=("$p"); done < <(interactive_exclude "$tier" "${pkgs2[@]}")

  if [ "${#final[@]}" -eq 0 ]; then
    return 0
  fi

  echo
  printf "%s Install [%s] now? [Y/n] " "$BOLD" "$tier"
  read -r ans || true
  ans="${ans:-Y}"
  case "$ans" in
    Y|y|yes|YES) ;;
    *) printf "%s [%s] Skipped by user.\n" "$SKIP" "$tier"; return 0 ;;
  esac

  # Split into repo vs AUR before installing
  local -a repo_pkgs=()
  local -a aur_pkgs=()

  local tmp_class
  tmp_class="$(mktemp)"
  classify_packages "${final[@]}" >"$tmp_class"

  # Read first line (repo) NUL-delimited
  while IFS= read -r -d '' p; do repo_pkgs+=("$p"); done < <(awk 'BEGIN{RS="\n"; ORS=""} NR==1{print}' "$tmp_class")
  # Read second line (aur) NUL-delimited
  while IFS= read -r -d '' p; do aur_pkgs+=("$p"); done < <(awk 'BEGIN{RS="\n"; ORS=""} NR==2{print}' "$tmp_class")
  rm -f "$tmp_class"

  echo
  printf "%s [%s] Repo: %d | AUR: %d\n" "$OK" "$tier" "${#repo_pkgs[@]}" "${#aur_pkgs[@]}"

  local out
  out="$(mktemp)"
  spinner_start "Installing [$tier]"

  set +e
  {
    install_repo_pkgs "${repo_pkgs[@]}"
    install_aur_pkgs  "${aur_pkgs[@]}"
  } >"$out" 2>&1
  local code=$?
  set -e

  spinner_stop "$code" "Installed [$tier]"

  if [ "$VERBOSE" -eq 1 ] || [ "$code" -ne 0 ]; then
    if [ -s "$out" ]; then
      indent <"$out"
      printf "%s" "$RESET"
    fi
  fi

  rm -f "$out"
  return "$code"
}

###############################################################################
# MAIN
###############################################################################
printf "%s%sMaster package install%s (%s)\n" "$BOLD" "$CYAN" "$RESET" "$PKG_DIR"

RAN=0
FAILED=0

for entry in "${TIERS[@]}"; do
  tier="${entry%%:*}"
  file="${entry#*:}"

  if install_tier "$tier" "$file"; then
    RAN=$((RAN + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

printf "\n%sSUMMARY%s\n" "$BOLD" "$RESET"
printf "  %s tiers completed: %s\n" "$OK" "$RAN"
printf "  %s tiers failed:    %s\n" "$ERR" "$FAILED"

[ "$FAILED" -eq 0 ]
