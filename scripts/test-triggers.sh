#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/opencode-eval.sh"

SKILL_NAME="${1:-}"
RUNS="${2:-3}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: $0 rfhub-<name> [runs=3]" >&2
  exit 1
fi

SKILL_DIR=".apm/skills/$SKILL_NAME"
QUERIES_FILE="$SKILL_DIR/evals/eval_queries.json"
RESULTS_FILE="$SKILL_DIR/evals/trigger-results.json"

if [[ ! -d "$SKILL_DIR" ]]; then
  echo "Error: $SKILL_DIR not found" >&2
  exit 1
fi

if [[ ! -f "$QUERIES_FILE" ]]; then
  echo "Error: $QUERIES_FILE not found" >&2
  exit 1
fi

eval_require_tools || exit 1

echo "Testing trigger accuracy for $SKILL_NAME ($RUNS runs per query)"
echo "Model: $EVAL_MODEL"
echo "Queries file: $QUERIES_FILE"
echo ""

count=$(jq length "$QUERIES_FILE")
results=()

passed=0
failed=0

# One isolated project for the whole run: only this skill is visible and every
# tool except `skill` is disabled.
eval_make_project "$SKILL_DIR"
project="$EVAL_PROJECT_DIR"

for i in $(seq 0 $((count - 1))); do
  query=$(jq -r ".[$i].query" "$QUERIES_FILE")
  should_trigger=$(jq -r ".[$i].should_trigger" "$QUERIES_FILE")
  triggers=0

  for _run in $(seq 1 "$RUNS"); do
    events="$project/events.json"
    log="$project/opencode.log"
    eval_run "$project" "$query" "$events" "$log" || true
    eval_skill_triggered "$events" "$SKILL_NAME" && triggers=$((triggers + 1)) || true
  done

  trigger_rate=$(echo "scale=2; $triggers / $RUNS" | bc)

  if [[ "$should_trigger" == "true" ]]; then
    if (( triggers > 0 )); then
      status="PASS"
      passed=$((passed + 1))
    else
      status="FAIL"
      failed=$((failed + 1))
    fi
    label="should trigger"
  else
    if (( triggers == 0 )); then
      status="PASS"
      passed=$((passed + 1))
    else
      status="FAIL"
      failed=$((failed + 1))
    fi
    label="should NOT trigger"
  fi

  echo "[$status] ($label, rate: $triggers/$RUNS) $query"

  result=$(jq -n \
    --arg query "$query" \
    --argjson should_trigger "$should_trigger" \
    --argjson triggers "$triggers" \
    --argjson runs "$RUNS" \
    --arg trigger_rate "$trigger_rate" \
    --arg status "$status" \
    '{query: $query, should_trigger: $should_trigger, triggers: $triggers, runs: $runs, trigger_rate: ($trigger_rate | tonumber), status: $status}')
  results+=("$result")
done

echo ""
echo "Results: $passed passed, $failed failed out of $count queries"

printf '%s\n' "${results[@]}" | jq -s '.' > "$RESULTS_FILE"
echo "Saved to $RESULTS_FILE"

if (( failed > 0 )); then
  echo ""
  echo "Fix: review failing queries and update the description in SKILL.md"
  echo "Then re-run this script to verify improvement."
  exit 1
fi
