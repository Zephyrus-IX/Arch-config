#!/bin/sh

# Source all installation scripts
for f in installs/*.sh; do
  echo "Running $f"
  "$f"
done
