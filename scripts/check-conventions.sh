#!/usr/bin/env bash
# Convention-drift gate: .apm primitives must never prescribe Robocop-flagged
# patterns again. Regression test for issue #1 (Force Tags / VAR scope=TEST).
set -euo pipefail

ROOT="$PWD"
cd "$ROOT"

status=0
count=0

fail() {
  echo "FAIL [$1] $2" >&2
  echo "     file: $3" >&2
  status=1
}

# Forbidden patterns: name | regex | why
# Each .apm primitive is scanned; a hit means the package is prescribing a
# pattern Robocop flags (or contradicting an already-adopted convention).
check_pattern() {
  local name="$1"
  local regex="$2"
  local why="$3"
  local file="$4"
  local hits
  # Grep for the pattern but allow negated/teaching mentions:
  # a line that warns against the pattern is fine; a line that prescribes it is not.
  hits=$(grep -nE "$regex" "$file" 2>/dev/null || true)
  if [[ -n "$hits" ]]; then
    while IFS= read -r hit; do
      local lineno="${hit%%:*}"
      local line
      line=$(sed -n "${lineno}p" "$file")
      case "$line" in
        *"Do not"*|*"do not"*|*"don't"*|*"not \`"*|*"never"*|*"Never"*|*"Wrong:"*|*"wrong:"*|*"instead"*)
          # Teaching reference to the anti-pattern — allowed.
          ;;
        *)
          fail "$name" "$why (line $lineno: ${line:0:120})" "$file"
          ;;
      esac
    done <<< "$hits"
  fi
  count=$((count + 1))
}

while IFS= read -r f; do
  [[ -n "$f" ]] || continue

  # Robot tag conventions: hub uses Test Tags, not Force Tags/Default Tags.
  check_pattern "no-force-tags" 'Force Tags' \
    "Prescribes 'Force Tags' — Robocop 0903 flags it; hub convention is 'Test Tags'" "$f"
  check_pattern "no-default-tags" 'Default Tags' \
    "Prescribes 'Default Tags' — hub convention is 'Test Tags'" "$f"

  # Variable handoff: Set Suite Variable, not VAR scope=TEST/SUITE.
  check_pattern "no-var-scope-test" 'VAR[^ ]* .*scope=TEST' \
    "Prescribes 'VAR … scope=TEST' — Robocop VAR06/no-test-variable flags it; use Set Suite Variable" "$f"
  check_pattern "no-var-scope-suite" 'VAR[^ ]* .*scope=SUITE' \
    "Prescribes 'VAR … scope=SUITE' — use Set Suite Variable (Robocop-clean handoff)" "$f"

  # Set Test Variable / Set Global Variable are also Robocop-sensitive handoffs
  # the package decided against; only Set Suite Variable is the blessed form.
  check_pattern "no-set-test-variable" 'Set Test Variable' \
    "Prescribes 'Set Test Variable' — package convention is Set Suite Variable" "$f"
  check_pattern "no-set-global-variable" 'Set Global Variable' \
    "Prescribes 'Set Global Variable' — package convention is Set Suite Variable" "$f"

  # Skill structure sanity: every SKILL.md must keep name/description/license frontmatter.
  if [[ "$f" == */SKILL.md ]]; then
    for field in '^name:' '^description:' '^license:'; do
      if ! grep -qE "$field" "$f"; then
        fail "skill-frontmatter" "SKILL.md missing required frontmatter field ($field)" "$f"
      fi
      count=$((count + 1))
    done
  fi
done <<EOF
$(find .apm -name '*.md' | sort)
EOF

if [[ "$count" -eq 0 ]]; then
  echo "Error: no markdown found under .apm/" >&2
  exit 1
fi

if [[ "$status" -ne 0 ]]; then
  echo "" >&2
  echo "convention-drift gate FAILED — fix the primitives above" >&2
  exit 1
fi

echo "conventions ok ($count check(s) over $(find .apm -name '*.md' | wc -l | tr -d ' ') file(s))"
