#!/usr/bin/env bash
# Enforces ADR-0003. The simulator and the control plane share only the wire.
set -euo pipefail

if [ -z "$(go list ./... 2>/dev/null)" ]; then
  echo "no packages yet, skipping"
  exit 0
fi

fail=0
while read -r pkg imports; do
  case "$pkg" in
    */internal/sim/*|*/internal/sim)   forbidden="/internal/anvil" ;;
    */internal/anvil/*|*/internal/anvil) forbidden="/internal/sim" ;;
    *) continue ;;
  esac
  for imp in $imports; do
    case "$imp" in
      *"$forbidden"/*|*"$forbidden")
        echo "boundary violation: $pkg imports $imp"
        fail=1
        ;;
    esac
  done
done < <(go list -f '{{.ImportPath}}{{range .Imports}} {{.}}{{end}}' ./...)

if [ "$fail" -ne 0 ]; then
  echo
  echo "internal/sim and internal/anvil must not import each other."
  echo "Shared wire types and fault identifiers belong in internal/wire."
  exit 1
fi
echo "boundaries ok"
