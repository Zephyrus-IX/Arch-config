#!/bin/sh

EXCLUDE="
install-proton-mail.sh
"

should_exclude() {
  for e in $EXCLUDE; do
    [ "$(basename "$1")" = "$e" ] && return 0
  done
  return 1
}

for f in installs/*.sh; do
  should_exclude "$f" && {
    echo "Skipping $f"
    continue
  }

  echo "Running $f"
  sh "$f"
done

