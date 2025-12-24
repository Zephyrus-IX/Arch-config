#!/bin/sh
set -eu

###############################################################################
# CONFIG
###############################################################################

# Directory containing install scripts
INSTALL_DIR="installs"

# Exclude list by filename (basename only)
EXCLUDE="
"

# Default type if a script doesn't specify one
DEFAULT_TYPE="apps"

###############################################################################
# PRETTY OUTPUT (colors/icons)
###############################################################################

if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED= GREEN= YELLOW= BLUE= CYAN= BOLD= DIM= RESET=
fi

OK="${GREEN}✔${RESET}"
ERR="${RED}✖${RESET}"
SKIP="${YELLOW}↷${RESET}"
RUN="${CYAN}▶${RESET}"

indent() { sed "s/^/${BLUE}│${RESET} /"; }

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

# Map type string -> numeric weight for sorting
type_weight() {
  case "$1" in
    base)     echo 0 ;;
    helpers)  echo 10 ;;
    core)     echo 20 ;;
    services) echo 30 ;;
    apps)     echo 40 ;;
    cosmetic) echo 50 ;;
    *)        echo 60 ;; # unknown types go last
  esac
}

# Extract INSTALL_TYPE=... from the script without executing it
get_type() {
  # allow optional spaces like: INSTALL_TYPE = apps  (we'll normalize)
  # We keep it simple: find first matching line and strip spaces.
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
# SPINNER (start/stop)
###############################################################################

spinner_start() {
  SPIN_MSG=$1
  SPIN_CHARS='|/-\'
  SPIN_i=0

  # Hide cursor
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

  # Clear line + show cursor
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

  # Print output after completion (indented & dimmed)
  if [ -s "$out" ]; then
    printf "%s" "$DIM"
    indent <"$out"
    printf "%s" "$RESET"
  fi

  rm -f "$out"
  return "$code"
}

###############################################################################
# MAIN
###############################################################################

# Ensure we have scripts
if ! ls "$INSTALL_DIR"/*.sh >/dev/null 2>&1; then
  echo "No install scripts found in: $INSTALL_DIR/*.sh"
  exit 0
fi

# Build a sorted execution list: weight type + filename (stable)
tmp="$(mktemp)"
for f in "$INSTALL_DIR"/*.sh; do
  if should_exclude "$f"; then
    continue
  fi
  t="$(get_type "$f")"
  w="$(type_weight "$t")"
  # pad weight to keep lexicographic sort stable
  printf "%03d %s %s\n" "$w" "$t" "$f" >> "$tmp"
done

TOTAL="$(wc -l < "$tmp" | tr -d ' ')"
RAN=0
SKIPPED=0
FAILED=0

printf "%s%sMaster install%s (%s scripts)\n" "$BOLD" "$CYAN" "$RESET" "$TOTAL"

# Run in sorted order
sort -k1,1n -k2,2 -k3,3 "$tmp" | while IFS= read -r line; do
  # extract the filepath (3rd field onward)
  # line format: "NNN type /path/to/file"
  f="$(printf "%s" "$line" | cut -d' ' -f3-)"
  name="$(basename "$f")"

  # (Exclude list is already applied above, but keep this safe if you edit later)
  if should_exclude "$f"; then
    printf "%s [%s] %s\n" "$SKIP" "excluded" "$name"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if run_script "$f"; then
    RAN=$((RAN + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

rm -f "$tmp"

# Summary
printf "\n%sSUMMARY%s\n" "$BOLD" "$RESET"
printf "  %s ran:     %s\n" "$OK" "$RAN"
printf "  %s skipped: %s\n" "$SKIP" "$SKIPPED"
printf "  %s failed:  %s\n" "$ERR" "$FAILED"

# Non-zero if any failed
[ "$FAILED" -eq 0 ]

