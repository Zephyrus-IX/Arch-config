#!/usr/bin/env bash
set -euo pipefail

# Run from repo root (or we try to find it)
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  cd "$REPO_ROOT"
else
  echo "Error: not inside a git repo."
  exit 1
fi

if [[ ! -f .gitmodules ]]; then
  echo "No .gitmodules found. This repo has no submodules."
  exit 0
fi

echo "Initializing submodules (safe to re-run)..."
git submodule update --init --recursive

# Get list of submodule paths
mapfile -t SUBMODULE_PATHS < <(git config --file .gitmodules --name-only --get-regexp path \
  | sed 's/^submodule\.//; s/\.path$//' \
  | while read -r name; do
      git config --file .gitmodules "submodule.${name}.path"
    done)

if [[ ${#SUBMODULE_PATHS[@]} -eq 0 ]]; then
  echo "No submodules found in .gitmodules."
  exit 0
fi

echo
echo "Submodules:"
for i in "${!SUBMODULE_PATHS[@]}"; do
  path="${SUBMODULE_PATHS[$i]}"
  # Show current pinned commit (if available)
  pinned="$(git submodule status "$path" 2>/dev/null | awk '{print $1}')"
  echo "  [$((i+1))] $path  (pinned: ${pinned#-})"
done
echo
echo "Choose which submodules to update:"
echo "  - Enter numbers separated by spaces (e.g. 1 3)"
echo "  - Enter 'a' for all"
echo "  - Enter 'q' to quit"
read -r -p "> " choice

if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
  echo "Cancelled."
  exit 0
fi

selected_paths=()
if [[ "$choice" == "a" || "$choice" == "A" ]]; then
  selected_paths=("${SUBMODULE_PATHS[@]}")
else
  # Parse numeric selections
  for token in $choice; do
    if [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#SUBMODULE_PATHS[@]} )); then
      selected_paths+=("${SUBMODULE_PATHS[$((token-1))]}")
    else
      echo "Invalid selection: '$token'"
      exit 1
    fi
  done
fi

echo
echo "Updating selected submodules (tracking their configured branch)..."
for path in "${selected_paths[@]}"; do
  echo "==> $path"
  # Fetch inside the submodule, then update it to its remote-tracking branch
  git -C "$path" fetch --all --prune
  git submodule update --remote --merge "$path"
done

echo
echo "Submodule update complete."

# Optional: offer to commit the updated submodule pointers
if ! git diff --quiet; then
  echo
  git status --short
  read -r -p "Commit these submodule pointer updates? (y/N) " do_commit
  if [[ "$do_commit" == "y" || "$do_commit" == "Y" ]]; then
    read -r -p "Commit message (default: 'Update submodules'): " msg
    msg="${msg:-Update submodules}"
    git add .gitmodules "${selected_paths[@]}"
    git commit -m "$msg"
    echo "Committed."
  else
    echo "Not committed. You can review/commit later."
  fi
else
  echo "No changes to commit."
fi