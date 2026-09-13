#!/usr/bin/env bash
# Emit a Markdown summary of the latest trigger-eval results.
# Reads .apm/skills/*/evals/trigger-results.json (written by test-triggers.sh).
# Safe to run when no results exist. Always exits 0 — it is report-only.
set -euo pipefail

shopt -s nullglob
files=(.apm/skills/*/evals/trigger-results.json)
shopt -u nullglob

echo "## Skill trigger evals"
echo

if [[ ${#files[@]} -eq 0 ]]; then
  echo "_No trigger results found — did the evals run?_"
  exit 0
fi

echo "- Model: \`${EVAL_MODEL:-(harness default)}\`"
echo

total_q=0
total_pass=0
total_fail=0
rows=()
fail_rows=()

for f in "${files[@]}"; do
  skill=$(basename "$(dirname "$(dirname "$f")")")

  read -r q p nf < <(jq -r \
    '[length, ([.[] | select(.status == "PASS")] | length), ([.[] | select(.status == "FAIL")] | length)] | @tsv' \
    "$f")

  total_q=$((total_q + q))
  total_pass=$((total_pass + p))
  total_fail=$((total_fail + nf))
  rows+=("| \`$skill\` | $p | $nf | $q |")

  while IFS= read -r line; do
    [[ -n "$line" ]] && fail_rows+=("$line")
  done < <(jq -r --arg skill "$skill" \
    '.[] | select(.status == "FAIL")
     | "| `" + $skill + "` | `" + (.query | gsub("`"; "\\`")) + "` | "
       + (if .should_trigger then "should trigger" else "should not trigger" end)
       + " | " + (.triggers | tostring) + "/" + (.runs | tostring) + " |"' \
    "$f")
done

echo "Skills: ${#files[@]} · Queries: $total_q · Passed: $total_pass · Failed: $total_fail"
echo
echo "| Skill | Passed | Failed | Total |"
echo "|---|---:|---:|---:|"
printf '%s\n' "${rows[@]}"

if [[ ${#fail_rows[@]} -gt 0 ]]; then
  echo
  echo "### Failures"
  echo
  echo "| Skill | Query | Expectation | Rate |"
  echo "|---|---|---|---|"
  printf '%s\n' "${fail_rows[@]}"
fi
