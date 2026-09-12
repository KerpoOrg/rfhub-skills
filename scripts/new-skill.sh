#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="${1:-}"

if [[ -z "$SKILL_NAME" ]]; then
  echo "Usage: $0 rfhub-<name>   (or rfhub for the map skill)" >&2
  exit 1
fi

if [[ ! "$SKILL_NAME" =~ ^rfhub(-[a-z0-9]+)*$ ]]; then
  echo "Error: skill name must match 'rfhub' or 'rfhub-<lowercase-alphanumeric-with-hyphens>'" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="$ROOT/.apm/skills/$SKILL_NAME"

if [[ -d "$SKILL_DIR" ]]; then
  echo "Error: $SKILL_DIR already exists" >&2
  exit 1
fi

mkdir -p "$SKILL_DIR/evals"

cat > "$SKILL_DIR/SKILL.md" << EOF
---
name: $SKILL_NAME
description: >-
  Use when the user... Apply when... Describe what this skill does and when
  to activate it. Include keywords users might say. Max 1024 characters.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# $SKILL_NAME

Brief description of what this skill does.

## When to use

- Situation A
- Situation B

## Instructions

Step-by-step guidance here. Keep lean — agent knows general programming.
Focus on hub-specific conventions and non-obvious details.

## Gotchas

- Non-obvious facts the agent wouldn't know without this skill
- Edge cases that cause mistakes without explicit guidance
EOF

cat > "$SKILL_DIR/evals/evals.json" << EOF
{
  "skill_name": "$SKILL_NAME",
  "evals": [
    {
      "id": 1,
      "prompt": "Realistic user message that should activate this skill.",
      "expected_output": "Human-readable description of what success looks like.",
      "assertions": []
    },
    {
      "id": 2,
      "prompt": "Another realistic prompt with different phrasing.",
      "expected_output": "Description of expected output.",
      "assertions": []
    }
  ]
}
EOF

cat > "$SKILL_DIR/evals/eval_queries.json" << EOF
[
  {"query": "Message that should trigger this skill", "should_trigger": true},
  {"query": "Message with same topic but different intent — should NOT trigger", "should_trigger": false}
]
EOF

echo "Created $SKILL_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit $SKILL_DIR/SKILL.md — write instructions and gotchas"
echo "  2. Fill $SKILL_DIR/evals/eval_queries.json"
echo "  3. Fill $SKILL_DIR/evals/evals.json"
echo "  4. Validate: apm audit --file .apm/skills/$SKILL_NAME/SKILL.md"
echo "  5. Preview:  apm install --dry-run --target cursor"
