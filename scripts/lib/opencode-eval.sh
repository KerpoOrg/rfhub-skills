#!/usr/bin/env bash
# Shared OpenCode harness for rfhub-skills trigger and output evals.
#
# Each run gets a throwaway project directory containing an opencode.json that
# (a) hides every skill except the one under test and (b) disables every tool
# except `skill`. That keeps runs hermetic (no wandering into the surrounding
# checkout, no global skills leaking in) and makes free-model runs fast/cheap.
#
# Model selection:
#   EVAL_MODEL        provider/model (default: a free OpenCode Zen model)
#   EVAL_TIMEOUT      per-call wall-clock seconds (default: 180)
#   EVAL_OPENCODE_BIN opencode binary (default: opencode)
#
# shellcheck shell=bash

EVAL_MODEL="${EVAL_MODEL:-opencode/muse-spark-1.3-contributor-free}"
EVAL_TIMEOUT="${EVAL_TIMEOUT:-180}"
EVAL_OPENCODE_BIN="${EVAL_OPENCODE_BIN:-opencode}"

_eval_tmpdirs=()

_eval_cleanup() {
  local d
  for d in "${_eval_tmpdirs[@]}"; do
    [[ -n "$d" ]] && rm -rf "$d"
  done
}

trap _eval_cleanup EXIT

eval_require_tools() {
  local missing=0 tool
  for tool in "$EVAL_OPENCODE_BIN" jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Error: '$tool' is required for skill evals" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    echo "Install OpenCode (https://opencode.ai), run 'opencode auth login', pick a free model" >&2
    echo "with EVAL_MODEL=provider/model, or point EVAL_OPENCODE_BIN at the binary." >&2
    return 1
  fi
}

# Hides the user's globally configured MCP servers so evals never touch the
# network beyond the model endpoint.
_eval_mcp_off() {
  local mcp
  mcp="$("$EVAL_OPENCODE_BIN" debug config 2>/dev/null \
    | jq -c '.mcp // {} | keys | map({(.): {enabled: false}}) | add // {}' 2>/dev/null || true)"
  [[ -n "$mcp" ]] || mcp='{}'
  printf '%s' "$mcp"
}

# eval_make_project <skill-dir|->  ->  sets EVAL_PROJECT_DIR
# A real directory loads just that skill; "-" exposes no skills at all.
eval_make_project() {
  local skill_dir="$1"
  local dir name perm mcp
  dir="$(mktemp -d "${TMPDIR:-/tmp}/rfhub-eval.XXXXXX")"
  _eval_tmpdirs+=("$dir")
  # Read by the sourcing script after this function returns.
  # shellcheck disable=SC2034
  EVAL_PROJECT_DIR="$dir"

  mcp="$(_eval_mcp_off)"

  if [[ "$skill_dir" == "-" ]]; then
    perm='{"skill":{"*":"deny"}}'
  else
    name="$(basename "$skill_dir")"
    perm="$(printf '{"skill":{"*":"deny","%s":"allow"}}' "$name")"
    mkdir -p "$dir/.opencode/skills/$name"
    cp -R "$skill_dir/." "$dir/.opencode/skills/$name/"
  fi

  jq -n \
    --argjson perm "$perm" \
    --argjson mcp "$mcp" \
    '{
      "$schema": "https://opencode.ai/config.json",
      permission: $perm,
      tools: {
        bash: false, read: false, write: false, edit: false, glob: false,
        grep: false, list: false, webfetch: false, task: false,
        todowrite: false, patch: false
      },
      mcp: $mcp
    }' > "$dir/opencode.json"
}

# eval_run <project-dir> <prompt> <events-out> <log-out>
# Returns the opencode exit code (124 on timeout); callers decide whether that
# is fatal.
eval_run() {
  local project="$1" prompt="$2" events="$3" log="$4"
  local rc=0
  if command -v timeout >/dev/null 2>&1; then
    (cd "$project" && timeout "$EVAL_TIMEOUT" \
      "$EVAL_OPENCODE_BIN" run "$prompt" --pure --model "$EVAL_MODEL" \
      --format json --auto) >"$events" 2>"$log" || rc=$?
  else
    (cd "$project" && \
      "$EVAL_OPENCODE_BIN" run "$prompt" --pure --model "$EVAL_MODEL" \
      --format json --auto) >"$events" 2>"$log" || rc=$?
  fi
  return "$rc"
}

# eval_skill_triggered <events-file> <skill-name>
eval_skill_triggered() {
  local events="$1" skill="$2"
  jq -s -e --arg s "$skill" \
    'any(.[]; .type=="tool_use" and .part.tool=="skill" and .part.state.input.name==$s)' \
    "$events" >/dev/null 2>&1
}

# eval_extract_text <events-file>
eval_extract_text() {
  jq -s -r '[.[] | select(.type=="text") | .part.text] | join("\n")' "$1" 2>/dev/null || true
}

# eval_total_tokens <events-file>
eval_total_tokens() {
  jq -s '[.[] | select(.type=="step_finish") | .part.tokens.total] | add // 0' "$1" 2>/dev/null || echo 0
}

# eval_total_cost <events-file>
eval_total_cost() {
  jq -s '[.[] | select(.type=="step_finish") | .part.cost] | add // 0' "$1" 2>/dev/null || echo 0
}

# eval_extract_json <text-file>
# Free models often wrap JSON in ```json fences; pull the first object out.
eval_extract_json() {
  python3 - "$1" <<'PY'
import json
import re
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
match = re.search(r"\{.*\}", text, re.S)
if not match:
    print("{}")
    raise SystemExit(0)
try:
    print(json.dumps(json.loads(match.group(0))))
except ValueError:
    print("{}")
PY
}
