#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${1:-}"
RUNS="${2:-3}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: $0 rfhub-<name> [runs=3]" >&2
  exit 1
fi

QUERIES_FILE=".apm/skills/$SKILL_NAME/evals/eval_queries.json"
RESULTS_FILE=".apm/skills/$SKILL_NAME/evals/trigger-results.json"

if [[ ! -f "$QUERIES_FILE" ]]; then
  echo "Error: $QUERIES_FILE not found" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required" >&2
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "Error: claude CLI is required for skill testing" >&2
  exit 1
fi

check_triggered() {
  local query="$1"
  claude -p "$query" --model haiku --output-format json 2>/dev/null \
    | jq -s -e --arg skill "$SKILL_NAME" \
      'any(.[]; .type == "assistant" and (.message.content[]? | .type == "tool_use" and .name == "Skill" and .input.skill == $skill))' \
      > /dev/null 2>&1
}

echo "Testing trigger accuracy for $SKILL_NAME ($RUNS runs per query)"
echo "Queries file: $QUERIES_FILE"
echo ""

count=$(jq length "$QUERIES_FILE")
results=()

passed=0
failed=0

for i in $(seq 0 $((count - 1))); do
  query=$(jq -r ".[$i].query" "$QUERIES_FILE")
  should_trigger=$(jq -r ".[$i].should_trigger" "$QUERIES_FILE")
  triggers=0

  for _run in $(seq 1 "$RUNS"); do
    check_triggered "$query" && triggers=$((triggers + 1)) || true
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
