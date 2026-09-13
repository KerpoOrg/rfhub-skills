#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/opencode-eval.sh"

SKILL_NAME="${1:-}"
ITERATION="${2:-1}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: $0 rfhub-<name> [iteration=1]" >&2
  exit 1
fi

SKILL_DIR=".apm/skills/$SKILL_NAME"
EVALS_FILE="$SKILL_DIR/evals/evals.json"
WORKSPACE="${SKILL_NAME}-workspace/iteration-${ITERATION}"

if [[ ! -f "$EVALS_FILE" ]]; then
  echo "Error: $EVALS_FILE not found" >&2
  exit 1
fi

eval_require_tools || exit 1

# Two isolated projects: one exposing just this skill, one exposing no skills.
# Grading reuses the no-skill project so it cannot load the skill under test.
eval_make_project "$SKILL_DIR"
WITH_PROJECT="$EVAL_PROJECT_DIR"
eval_make_project -
WITHOUT_PROJECT="$EVAL_PROJECT_DIR"

run_eval() {
  local prompt="$1"
  local mode="$2"     # with_skill | without_skill
  local eval_dir="$3"

  local out_dir="$WORKSPACE/$eval_dir/$mode"
  mkdir -p "$out_dir/outputs"

  local project
  if [[ "$mode" == "with_skill" ]]; then
    project="$WITH_PROJECT"
  else
    project="$WITHOUT_PROJECT"
  fi

  local start_ms end_ms duration_ms
  # Portable ms timestamp (macOS date lacks %3N)
  start_ms=$(python3 -c 'import time; print(int(time.time()*1000))')

  local events="$out_dir/events.json"
  local log="$out_dir/opencode.log"
  eval_run "$project" "$prompt" "$events" "$log" || true

  end_ms=$(python3 -c 'import time; print(int(time.time()*1000))')
  duration_ms=$((end_ms - start_ms))

  local total_tokens cost
  total_tokens=$(eval_total_tokens "$events")
  cost=$(eval_total_cost "$events")

  jq -n \
    --argjson total_tokens "$total_tokens" \
    --argjson duration_ms "$duration_ms" \
    --argjson cost "$cost" \
    '{total_tokens: $total_tokens, duration_ms: $duration_ms, cost: $cost}' \
    > "$out_dir/timing.json"

  eval_extract_text "$events" > "$out_dir/outputs/response.txt"

  echo "  [$mode] tokens: $total_tokens, cost: $cost, duration: ${duration_ms}ms"
}

grade_eval() {
  local eval_dir="$1"
  local assertions_json="$2"
  local mode="$3"

  local out_dir="$WORKSPACE/$eval_dir/$mode"
  local response_file="$out_dir/outputs/response.txt"

  if [[ ! -f "$response_file" ]]; then
    echo '{"assertion_results": [], "summary": {"passed": 0, "failed": 0, "total": 0, "pass_rate": 0}}' \
      > "$out_dir/grading.json"
    return
  fi

  local assertion_count
  assertion_count=$(echo "$assertions_json" | jq length)

  if (( assertion_count == 0 )); then
    echo '{"assertion_results": [], "summary": {"passed": 0, "failed": 0, "total": 0, "pass_rate": null, "note": "No assertions defined yet — add assertions to evals.json after reviewing first outputs"}}' \
      > "$out_dir/grading.json"
    return
  fi

  local grading_prompt
  grading_prompt="You are grading AI skill output. For each assertion, output PASS or FAIL with brief evidence from the actual output.

Output to grade:
$(cat "$response_file")

Assertions to check:
$assertions_json

Respond with JSON only:
{
  \"assertion_results\": [
    {\"text\": \"assertion text\", \"passed\": true/false, \"evidence\": \"specific quote or observation\"}
  ]
}"

  local grading_events="$out_dir/grading.events.json"
  eval_run "$WITHOUT_PROJECT" "$grading_prompt" "$grading_events" "$out_dir/grading.log" || true
  eval_extract_text "$grading_events" > "$out_dir/grading.raw.txt"

  local grading_json
  grading_json=$(eval_extract_json "$out_dir/grading.raw.txt")

  local passed failed total pass_rate
  passed=$(echo "$grading_json" | jq '[.assertion_results[] | select(.passed == true)] | length' 2>/dev/null || echo 0)
  failed=$(echo "$grading_json" | jq '[.assertion_results[] | select(.passed == false)] | length' 2>/dev/null || echo 0)
  total=$((passed + failed))
  pass_rate=$(echo "scale=2; $passed / $total" | bc 2>/dev/null || echo 0)

  echo "$grading_json" | jq \
    --argjson passed "$passed" \
    --argjson failed "$failed" \
    --argjson total "$total" \
    --arg pass_rate "$pass_rate" \
    '. + {summary: {passed: $passed, failed: $failed, total: $total, pass_rate: ($pass_rate | tonumber)}}' \
    > "$out_dir/grading.json" 2>/dev/null || true

  echo "  [$mode] grade: $passed/$total assertions passed"
}

mkdir -p "$WORKSPACE"

echo "Running evals for $SKILL_NAME (iteration $ITERATION)"
echo "Model: $EVAL_MODEL"
echo "Workspace: $WORKSPACE"
echo ""

count=$(jq 'if type == "array" then length else (.evals | length) end' "$EVALS_FILE")

for i in $(seq 0 $((count - 1))); do
  eval_id=$(jq -r 'if type == "array" then .[$i].id else .evals[$i].id end' --argjson i "$i" "$EVALS_FILE")
  prompt=$(jq -r 'if type == "array" then .[$i].prompt else .evals[$i].prompt end' --argjson i "$i" "$EVALS_FILE")
  assertions=$(jq -c 'if type == "array" then (.[$i].assertions // []) else (.evals[$i].assertions // []) end' --argjson i "$i" "$EVALS_FILE")
  eval_dir="eval-$(echo "$prompt" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | cut -c1-40 | sed 's/-*$//')"

  echo "Eval $eval_id: ${prompt:0:60}..."

  run_eval "$prompt" "with_skill" "$eval_dir"
  run_eval "$prompt" "without_skill" "$eval_dir"
  grade_eval "$eval_dir" "$assertions" "with_skill"
  grade_eval "$eval_dir" "$assertions" "without_skill"
  echo ""
done

echo "Generating benchmark.json..."

with_pass_rates=()
without_pass_rates=()
with_tokens=()
without_tokens=()

for eval_dir in "$WORKSPACE"/eval-*/; do
  [[ -d "$eval_dir" ]] || continue

  wp=$(jq -r '.summary.pass_rate // 0' "$eval_dir/with_skill/grading.json" 2>/dev/null || echo 0)
  nwp=$(jq -r '.summary.pass_rate // 0' "$eval_dir/without_skill/grading.json" 2>/dev/null || echo 0)
  wt=$(jq -r '.total_tokens // 0' "$eval_dir/with_skill/timing.json" 2>/dev/null || echo 0)
  nwt=$(jq -r '.total_tokens // 0' "$eval_dir/without_skill/timing.json" 2>/dev/null || echo 0)

  with_pass_rates+=("$wp")
  without_pass_rates+=("$nwp")
  with_tokens+=("$wt")
  without_tokens+=("$nwt")
done

jq -n \
  --argjson with_pass_rates "$(printf '%s\n' "${with_pass_rates[@]}" | jq -s '.')" \
  --argjson without_pass_rates "$(printf '%s\n' "${without_pass_rates[@]}" | jq -s '.')" \
  --argjson with_tokens "$(printf '%s\n' "${with_tokens[@]}" | jq -s '.')" \
  --argjson without_tokens "$(printf '%s\n' "${without_tokens[@]}" | jq -s '.')" \
  '{
    run_summary: {
      with_skill: {
        pass_rate: {mean: (($with_pass_rates | add) / ($with_pass_rates | length))},
        tokens: {mean: (($with_tokens | add) / ($with_tokens | length))}
      },
      without_skill: {
        pass_rate: {mean: (($without_pass_rates | add) / ($without_pass_rates | length))},
        tokens: {mean: (($without_tokens | add) / ($without_tokens | length))}
      },
      delta: {
        pass_rate: ((($with_pass_rates | add) / ($with_pass_rates | length)) - (($without_pass_rates | add) / ($without_pass_rates | length))),
        tokens: ((($with_tokens | add) / ($with_tokens | length)) - (($without_tokens | add) / ($without_tokens | length)))
      }
    }
  }' > "$WORKSPACE/benchmark.json" 2>/dev/null || echo '{}' > "$WORKSPACE/benchmark.json"

echo "Done. Results in $WORKSPACE/"
echo ""
cat "$WORKSPACE/benchmark.json"
echo ""
echo "Next: review outputs in $WORKSPACE/, then update evals/evals.json assertions"
echo "      Run next iteration: ./scripts/run-evals.sh $SKILL_NAME $((ITERATION + 1))"
