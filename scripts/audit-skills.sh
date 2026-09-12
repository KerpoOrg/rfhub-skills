#!/usr/bin/env bash
# Lightweight apm audit of all skill markdown. No evals, no LLM scanners.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v apm >/dev/null 2>&1; then
  echo "Error: apm not on PATH. Run via: mise run skills -- audit" >&2
  exit 1
fi

status=0
count=0
failed=""

while IFS= read -r f; do
  [ -n "$f" ] || continue
  count=$((count + 1))
  echo "==> $f"
  if ! apm audit --file "$f" --no-policy; then
    status=1
    failed="${failed}  ${f}"$'\n'
  fi
done <<EOF
$(find .apm/skills -name '*.md' | sort)
EOF

if [ "$count" -eq 0 ]; then
  echo "Error: no skill markdown under .apm/skills/" >&2
  exit 1
fi

echo
if [ "$status" -ne 0 ]; then
  echo "audit failed:" >&2
  printf '%s' "$failed" >&2
  exit "$status"
fi

echo "audit ok ($count files)"
