#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# INSTALL SETUP RUNNER
#
# Entry point: runs scripts in ./installation/scripts in numeric order
# (00-*, 10-*, 20-*...)
#
# Features:
# - Splash header
# - START_AT / STOP_AT controls
# - --list / --dry-run / --help
# - Optional interactive prompts (exclude menu + per-script confirm)
#
# IMPORTANT:
# - Runs child scripts in the FOREGROUND with the real TTY.
# - Do NOT redirect their output, or sudo/pacman/yay prompts will break.
###############################################################################

###############################################################################
# CONFIG / PATHS (single place to edit later)
###############################################################################
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Repo layout:
#   ./install-setup.sh
#   ./installation/scripts/*.sh
#   ./installation/packages/*.packages
INSTALLATION_DIR="$ROOT_DIR/installation"
SCRIPTS_DIR="$INSTALLATION_DIR/scripts"
PACKAGES_DIR="$INSTALLATION_DIR/packages"

# Defaults (can be overridden by env vars)
DEFAULT_START_AT=0
DEFAULT_STOP_AT=9999
DEFAULT_YES=0

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
DOT="${DIM}${BLUE}│${RESET}"

###############################################################################
# HELPERS (small + readable)
###############################################################################
die() {
  echo "install-setup: $*" >&2
  exit 1
}

is_int() {
  local s="${1:-}"
  [[ -n "$s" && "$s" =~ ^[0-9]+$ ]]
}

splash() {
  echo
  printf "%s%s┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓%s\n" "$BOLD" "$CYAN" "$RESET"
  printf "%s%s┃%s  Arch Hyprland Setup Runner                              %s%s┃%s\n" "$BOLD" "$CYAN" "$RESET" "$DIM" "$CYAN" "$RESET"
  printf "%s%s┃%s  Runs installation/scripts in order: 00-* → 10-* → ...   %s%s┃%s\n" "$BOLD" "$CYAN" "$RESET" "$DIM" "$CYAN" "$RESET"
  printf "%s%s┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛%s\n" "$BOLD" "$CYAN" "$RESET"
  echo
}

usage() {
  cat <<EOF
Usage:
  ./install-setup.sh [options]

Options:
  --start-at N      Start at step N (prefix number). Example: --start-at 30
  --stop-at N       Stop after step N (inclusive). Example: --stop-at 40
  --list            List detected scripts and exit
  --dry-run         Show what would run, but don't execute scripts
  -y, --yes         Non-interactive (don't prompt)
  -h, --help        Show this help

Environment variables (alternative to flags):
  START_AT=N
  STOP_AT=N
  YES=1
  SUDO_KEEPALIVE=1  (default: 1)

Examples:
  ./install-setup.sh
  ./install-setup.sh --start-at 30
  ./install-setup.sh --stop-at 40
  ./install-setup.sh --start-at 20 --stop-at 40
  YES=1 START_AT=30 ./install-setup.sh --dry-run
EOF
}

parse_step() {
  local base="${1:?basename required}"
  local prefix="${base%%-*}"
  if [[ "$prefix" =~ ^[0-9]+$ ]]; then
    echo $((10#$prefix))
  else
    echo 9999
  fi
}

###############################################################################
# ARG PARSING
###############################################################################
START_AT="${START_AT:-$DEFAULT_START_AT}"
STOP_AT="${STOP_AT:-$DEFAULT_STOP_AT}"
YES="${YES:-$DEFAULT_YES}"
DRY_RUN=0
LIST_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --start-at) shift; START_AT="${1:-}" ;;
    --stop-at)  shift; STOP_AT="${1:-}" ;;
    --list)     LIST_ONLY=1 ;;
    --dry-run)  DRY_RUN=1 ;;
    -y|--yes)   YES=1 ;;
    -h|--help)  splash; usage; exit 0 ;;
    *)
      echo "${ERR} Unknown argument: $1"
      echo
      usage
      exit 2
      ;;
  esac
  shift || true
done

is_int "$START_AT" || die "START_AT must be a non-negative integer"
is_int "$STOP_AT"  || die "STOP_AT must be a non-negative integer"
[ "$START_AT" -le "$STOP_AT" ] || die "START_AT ($START_AT) cannot be greater than STOP_AT ($STOP_AT)"

###############################################################################
# PRE-FLIGHT
###############################################################################
[ -d "$INSTALLATION_DIR" ] || die "missing installation directory: $INSTALLATION_DIR"
[ -d "$SCRIPTS_DIR" ] || die "missing scripts directory: $SCRIPTS_DIR"
[ -d "$PACKAGES_DIR" ] || die "missing packages directory: $PACKAGES_DIR"

mapfile -t FILES < <(
  find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '*.sh' | sort
)

[ "${#FILES[@]}" -gt 0 ] || {
  echo "${SKIP} No scripts found in: $SCRIPTS_DIR"
  exit 0
}

filtered_scripts=()
for f in "${FILES[@]}"; do
  base="$(basename "$f")"
  step="$(parse_step "$base")"
  [ "$step" -lt "$START_AT" ] && continue
  [ "$step" -gt "$STOP_AT" ] && continue
  filtered_scripts+=("$f")
done

###############################################################################
# UI: HEADER / LIST / DRY-RUN
###############################################################################
splash

printf "%sRepo:%s         %s\n" "$BOLD" "$RESET" "$ROOT_DIR"
printf "%sInstall dir:%s  %s\n" "$BOLD" "$RESET" "$INSTALLATION_DIR"
printf "%sScripts:%s      %s\n" "$BOLD" "$RESET" "$SCRIPTS_DIR"
printf "%sPackages:%s     %s\n" "$BOLD" "$RESET" "$PACKAGES_DIR"
printf "%sRange:%s        %s → %s\n" "$BOLD" "$RESET" "$START_AT" "$STOP_AT"
printf "%sMode:%s         %s\n" "$BOLD" "$RESET" "$([ "$DRY_RUN" -eq 1 ] && echo "dry-run" || echo "execute")"
echo

if [ "$LIST_ONLY" -eq 1 ]; then
  printf "%s%sDetected scripts%s\n" "$BOLD" "$CYAN" "$RESET"
  for f in "${FILES[@]}"; do
    base="$(basename "$f")"
    step="$(parse_step "$base")"
    printf "  %s%4s%s  %s\n" "$DIM" "$step" "$RESET" "$base"
  done

  echo
  printf "%s%sSelected scripts%s\n" "$BOLD" "$CYAN" "$RESET"
  if [ "${#filtered_scripts[@]}" -eq 0 ]; then
    printf "  %s(none in selected range)%s\n" "$DIM" "$RESET"
  else
    for f in "${filtered_scripts[@]}"; do
      base="$(basename "$f")"
      step="$(parse_step "$base")"
      printf "  %s%4s%s  %s\n" "$DIM" "$step" "$RESET" "$base"
    done
  fi
  exit 0
fi

if [ "${#filtered_scripts[@]}" -eq 0 ]; then
  echo "${SKIP} No scripts match the selected range."
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "${DIM}Dry run selected. Would run:${RESET}"
  for f in "${filtered_scripts[@]}"; do
    printf "  ${DOT} %s\n" "$(basename "$f")"
  done
  exit 0
fi

###############################################################################
# SUDO WARM-UP (prompt immediately on start)
###############################################################################
sudo -v

###############################################################################
# OPTIONAL CONFIRMATION
###############################################################################
if [ "$YES" -ne 1 ]; then
  echo "${DIM}This will run the following scripts in order:${RESET}"
  for f in "${filtered_scripts[@]}"; do
    printf "  ${DOT} %s\n" "$(basename "$f")"
  done
  echo
  printf "%sProceed?%s [Y/n] " "$BOLD" "$RESET"
  read -r ans || true
  ans="${ans:-Y}"
  case "$ans" in
    Y|y|yes|YES) ;;
    *) echo "${SKIP} Aborted."; exit 0 ;;
  esac
fi

###############################################################################
# SUDO KEEPALIVE (once for entire run)
###############################################################################
if [ "${SUDO_KEEPALIVE:-1}" -eq 1 ]; then
  ( while :; do sudo -n -v 2>/dev/null; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
  export SUDO_KEEPALIVE_PID
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT INT TERM
fi

###############################################################################
# OPTIONAL SCRIPT EXCLUSION / PER-SCRIPT PROMPT (interactive)
###############################################################################
# Behavior:
# - If YES=1: run everything (no prompts)
# - Else: user may exclude scripts by number/range, and is prompted per script.
###############################################################################
menu_items=()
for f in "${filtered_scripts[@]}"; do
  menu_items+=("$(basename "$f")")
done

declare -A EXCLUDED=()

apply_exclusions() {
  local input="${1:-}"
  local token start end i

  for token in $input; do
    if [[ "$token" =~ ^[0-9]+-[0-9]+$ ]]; then
      start="${token%-*}"
      end="${token#*-}"
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      start="$token"
      end="$token"
    else
      continue
    fi

    if [ "$start" -gt "$end" ]; then
      local tmp="$start"; start="$end"; end="$tmp"
    fi

    for ((i=start; i<=end; i++)); do
      if [ "$i" -ge 1 ] && [ "$i" -le "${#menu_items[@]}" ]; then
        EXCLUDED["${menu_items[$((i-1))]}"]=1
      fi
    done
  done
}

if [ "$YES" -ne 1 ]; then
  echo
  printf "%s%sDetected script steps%s\n" "$BOLD" "$CYAN" "$RESET"
  for i in "${!menu_items[@]}"; do
    idx=$((i+1))
    printf "  %s%2d)%s %s\n" "$DIM" "$idx" "$RESET" "${menu_items[$i]}"
  done

  echo
  printf "Select scripts to EXCLUDE (e.g. '1 3 7-9'), or press Enter to run all: "
  read -r exclude_sel || true
  if [ -n "${exclude_sel:-}" ]; then
    apply_exclusions "$exclude_sel"
  fi
fi

###############################################################################
# RUNNER (foreground, real TTY)
###############################################################################
RAN=0
FAILED=0

for f in "${filtered_scripts[@]}"; do
  base="$(basename "$f")"
  step="$(parse_step "$base")"

  if [ "$YES" -ne 1 ] && [ "${EXCLUDED[$base]+x}" = "x" ]; then
    echo
    printf "%s [%s] %s\n" "$SKIP" "$step" "$base"
    continue
  fi

  if [ "$YES" -ne 1 ]; then
    echo
    printf "%sRun %s%s%s now?%s [Y/n] " "$DIM" "$BOLD" "$base" "$RESET" "$RESET"
    read -r ans || true
    ans="${ans:-Y}"
    case "$ans" in
      Y|y|yes|YES) ;;
      *) printf "%s [%s] %s (skipped)\n" "$SKIP" "$step" "$base"; continue ;;
    esac
  fi

  echo
  printf "%s [%s] %s%s%s\n" "$RUN" "$step" "$BOLD" "$base" "$RESET"

  set +e
  bash "$f"
  code=$?
  set -e

  if [ "$code" -eq 0 ]; then
    printf "%s [%s] %s\n" "$OK" "$step" "$base"
    RAN=$((RAN + 1))
  else
    printf "%s [%s] %s\n" "$ERR" "$step" "$base"
    FAILED=$((FAILED + 1))
    echo
    echo "${ERR} Stopping due to failure."
    break
  fi
done

echo
printf "%sSUMMARY%s\n" "$BOLD" "$RESET"
printf "  %s ran:     %s\n" "$OK" "$RAN"
printf "  %s failed:  %s\n" "$ERR" "$FAILED"

[ "$FAILED" -eq 0 ]
