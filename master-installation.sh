#!/bin/sh
set -eu

###############################################################################
# USER CONFIG (edit these)
###############################################################################

# Show installer output:
# 1 = always show output (default)
# 0 = only show output when a script fails
VERBOSE=1

# Exclude list by filename (basename only), one per line.
EXCLUDE="
install-proton-mail.sh
"

# Keep sudo alive during run (prevents timeout mid-install)
# 1 = yes, 0 = no
SUDO_KEEPALIVE=1

# Auto-skip template scripts (recommended)
# 1 = yes, 0 = no
SKIP_TEMPLATES=1

###############################################################################
# SUDO WARM-UP (run anywhere as any user, without becoming root)
###############################################################################
# We want:
# - pacman calls to work via sudo in installers
# - yay/paru to run as the normal user (required for AUR builds)
sudo -v

if [ "$SUDO_KEEPALIVE" -eq 1 ]; then
  # Refresh sudo timestamp every 60s until script exits
  ( while :; do sudo -n -v 2>/dev/null; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT INT TERM
fi

###############################################################################
# INTERNAL CONFIG
###############################################################################
INSTALL_DIR="installs"
DEFAULT_TYPE="apps"

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
# EXCLUDE / TYPE PARSING
###############################################################################
should_exclude() {
  base="$(basename "$1")"
  for e in $EXCLUDE; do
    [ "$base" = "$e" ] && return 0
  done
  return 1
}

is_template() {
  # Skip install-template.sh and any *template*.sh if enabled
  [ "$SKIP_TEMPLATES" -eq 1 ] || return 1
  base="$(basename "$1")"
  case "$base" in
    *template*.sh) return 0 ;;
  esac
  return 1
}

type_weight() {
  case "$1" in
    base)     echo 0 ;;
    helpers)  echo 10 ;;
    core)     echo 20 ;;
    services) echo 30 ;;
    apps)     echo 40 ;;
    cosmetic) echo 50 ;;
    *)        echo 60 ;;
  esac
}

get_type() {
  t="$(
    sed -n 's/^[[:space:]]*INSTALL_TYPE[[:space:]]*=[[:space:]]*//p' "$1" \
    | head -n 1 \
    | tr -d '[:space:]'
  )"
  if [ -n "${t:-}" ]; then
    printf "%s" "$t"
  else
    printf "%s" "$DEFAULT_TYPE"
  fi
}

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
# RUNNER
###############################################################################
run_script() {
  f=$1
  name="$(basename "$f")"
  t="$(get_type "$f")"
  out="$(mktemp)"

  spinner_start "[$t] $name"
  sh "$f" >"$out" 2>&1
  code=$?
  spinner_stop "$code" "[$t] $name"

  # Print installer output as an indented block
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
if ! ls "$INSTALL_DIR"/*.sh >/dev/null 2>&1; then
  echo "No install scripts found in: $INSTALL_DIR/*.sh"
  exit 0
fi

tmp="$(mktemp)"
tmp_skip="$(mktemp)"
sorted="$(mktemp)"

for f in "$INSTALL_DIR"/*.sh; do
  if is_template "$f"; then
    printf "%s\n" "$(basename "$f")" >> "$tmp_skip"
    continue
  fi
  if should_exclude "$f"; then
    printf "%s\n" "$(basename "$f")" >> "$tmp_skip"
    continue
  fi

  t="$(get_type "$f")"
  w="$(type_weight "$t")"
  printf "%03d %s %s\n" "$w" "$t" "$f" >> "$tmp"
done

TOTAL_ALL="$(ls "$INSTALL_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')"
TOTAL_RUN="$(wc -l < "$tmp" | tr -d ' ')"
TOTAL_SKIP="$(wc -l < "$tmp_skip" | tr -d ' ')"

printf "%s%sMaster install%s (total: %s, run: %s, excluded: %s)\n" \
  "$BOLD" "$CYAN" "$RESET" "$TOTAL_ALL" "$TOTAL_RUN" "$TOTAL_SKIP"

RAN=0
FAILED=0

# IMPORTANT: avoid a pipeline here (would run loop in a subshell in /bin/sh)
sort -k1,1n -k2,2 -k3,3 "$tmp" > "$sorted"

while IFS= read -r line; do
  f="$(printf "%s" "$line" | cut -d' ' -f3-)"
  if run_script "$f"; then
    RAN=$((RAN + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done < "$sorted"

if [ "$TOTAL_SKIP" -gt 0 ]; then
  printf "\n%sExcluded scripts:%s\n" "$BOLD" "$RESET"
  sort "$tmp_skip" | sed "s/^/  $SKIP /"
fi

rm -f "$tmp" "$tmp_skip" "$sorted"

printf "\n%sSUMMARY%s\n" "$BOLD" "$RESET"
printf "  %s ran:     %s\n" "$OK" "$RAN"
printf "  %s failed:  %s\n" "$ERR" "$FAILED"
printf "  %s excluded:%s\n" "$SKIP" "$TOTAL_SKIP"

[ "$FAILED" -eq 0 ]
