#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# install-setup.sh
# Entry point: runs scripts in /scripts in numeric order (00-*, 10-*, 20-*...)
#
# Features:
# - Splash header
# - START_AT / STOP_AT controls
# - --list / --dry-run / --help
# - Optional interactive prompt when run with no args
###############################################################################

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

###############################################################################
# PRETTY OUTPUT (colors/icons)  (kept consistent with your style)
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

indent() { sed "s/^/${DIM}${BLUE}│${RESET}${DIM}    /"; }

###############################################################################
# SPLASH
###############################################################################
splash() {
  echo
  printf "%s%s┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓%s\n" "$BOLD" "$CYAN" "$RESET"
  printf "%s%s┃%s  Arch Hyprland Setup Runner                             %s%s┃%s\n" "$BOLD" "$CYAN" "$RESET" "$DIM" "$CYAN" "$BOLD" "$RESET"
  printf "%s%s┃%s  Runs scripts/ in order: 00-* → 10-* → 20-* ...         %s%s┃%s\n" "$BOLD" "$CYAN" "$RESET" "$DIM" "$CYAN" "$BOLD" "$RESET"
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

Examples:
  ./install-setup.sh
  ./install-setup.sh --start-at 30
  ./install-setup.sh --stop-at 40
  ./install-setup.sh --start-at 20 --stop-at 40
  YES=1 START_AT=30 ./install-setup.sh --dry-run
EOF
}

###############################################################################
# ARG PARSING
###############################################################################
START_AT="${START_AT:-0}"
STOP_AT="${STOP_AT:-9999}"
DRY_RUN=0
LIST_ONLY=0
YES="${YES:-0}"

while [ $# -gt 0 ]; do
  case "$1" in
    --start-at)
      shift
      START_AT="${1:-}"
      ;;
    --stop-at)
      shift
      STOP_AT="${1:-}"
      ;;
    --list)
      LIST_ONLY=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -y|--yes)
      YES=1
      ;;
    -h|--help)
      splash
      usage
      exit 0
      ;;
    *)
      echo "${ERR} Unknown argument: $1"
      echo
      usage
      exit 2
      ;;
  esac
  shift || true
done

# Validate numeric inputs
case "$START_AT" in
  ''|*[!0-9]*)
    echo "${ERR} START_AT must be a non-negative integer"
    exit 2
    ;;
esac

case "$STOP_AT" in
  ''|*[!0-9]*)
    echo "${ERR} STOP_AT must be a non-negative integer"
    exit 2
    ;;
esac

if [ "$START_AT" -gt "$STOP_AT" ]; then
  echo "${ERR} START_AT ($START_AT) cannot be greater than STOP_AT ($STOP_AT)"
  exit 2
fi

###############################################################################
# DISCOVER SCRIPTS
###############################################################################
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "${ERR} Missing scripts directory: $SCRIPTS_DIR"
  exit 1
fi

mapfile -t FILES < <(
  find "$SCRIPTS_DIR" -maxdepth 1 -type f -name '*.sh' \
  | sort
)

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "${SKIP} No scripts found in: $SCRIPTS_DIR"
  exit 0
fi

parse_step() {
  # Extract numeric prefix before first dash: "30-services.sh" -> 30
  # If missing or malformed, returns 9999 so it runs last.
  local base="$1"
  local prefix="${base%%-*}"
  if [[ "$prefix" =~ ^[0-9]+$ ]]; then
    # base-10 normalize: "00" -> 0
    echo $((10#$prefix))
  else
    echo 9999
  fi
}

filtered_scripts=()
for f in "${FILES[@]}"; do
  base="$(basename "$f")"
  step="$(parse_step "$base")"
  if [ "$step" -lt "$START_AT" ]; then
    continue
  fi
  if [ "$step" -gt "$STOP_AT" ]; then
    continue
  fi
  filtered_scripts+=("$f")
done

###############################################################################
# LIST / DRY RUN
###############################################################################
splash

printf "%sRepo:%s      %s\n" "$BOLD" "$RESET" "$ROOT_DIR"
printf "%sScripts:%s   %s\n" "$BOLD" "$RESET" "$SCRIPTS_DIR"
printf "%sRange:%s     %s → %s\n" "$BOLD" "$RESET" "$START_AT" "$STOP_AT"
printf "%sMode:%s      %s\n" "$BOLD" "$RESET" "$([ "$DRY_RUN" -eq 1 ] && echo "dry-run" || echo "execute")"
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

# If user ran with no args and hasn't opted out, show a short explainer + prompt.
if [ "$YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  echo "${DIM}This will run the following scripts in order:${RESET}"
  for f in "${filtered_scripts[@]}"; do
    base="$(basename "$f")"
    printf "  ${DOT} %s\n" "$base"
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

if [ "$DRY_RUN" -eq 1 ]; then
  echo "${DIM}Dry run selected. Would run:${RESET}"
  for f in "${filtered_scripts[@]}"; do
    base="$(basename "$f")"
    printf "  ${DOT} %s\n" "$base"
  done
  exit 0
fi

###############################################################################
# RUNNER
###############################################################################
RAN=0
FAILED=0

for f in "${filtered_scripts[@]}"; do
  base="$(basename "$f")"
  step="$(parse_step "$base")"

  echo
  printf "%s [%s] %s%s%s\n" "$RUN" "$step" "$BOLD" "$base" "$RESET"

  out="$(mktemp)"
  set +e
  bash "$f" >"$out" 2>&1
  code=$?
  set -e

  if [ "$code" -eq 0 ]; then
    printf "%s [%s] %s\n" "$OK" "$step" "$base"
    RAN=$((RAN + 1))
  else
    printf "%s [%s] %s\n" "$ERR" "$step" "$base"
    FAILED=$((FAILED + 1))
  fi

  # Print script output as an indented block (always if VERBOSE=1, else only on failure)
  if [ "${VERBOSE:-1}" -eq 1 ] || [ "$code" -ne 0 ]; then
    if [ -s "$out" ]; then
      indent <"$out"
      printf "%s" "$RESET"
    fi
  fi

  rm -f "$out"

  if [ "$code" -ne 0 ]; then
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
