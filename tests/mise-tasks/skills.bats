#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$PROJECT_ROOT"
  unset usage_cmd || true
}

@test "skills USAGE declares all subcommands" {
  run grep -E '^#USAGE cmd "' .mise/tasks/skills
  [ "$status" -eq 0 ]
  [[ "$output" == *'cmd "audit"'* ]]
  [[ "$output" == *'cmd "lint"'* ]]
  [[ "$output" == *'cmd "evals"'* ]]
  [[ "$output" == *'cmd "triggers"'* ]]
  [[ "$output" == *'cmd "conventions"'* ]]
  [[ "$output" == *'cmd "validate"'* ]]
}

@test "skills without subcommand prints brief usage" {
  run env -u usage_cmd ./.mise/tasks/skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: mise run skills"* ]]
  [[ "$output" == *"audit"* ]]
  [[ "$output" == *"triggers"* ]]
  [[ "$output" == *"conventions"* ]]
}

@test "skills with unknown subcommand fails" {
  run env usage_cmd=bogus ./.mise/tasks/skills
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "skills conventions gate passes on current primitives" {
  run env usage_cmd=conventions ./.mise/tasks/skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"conventions ok"* ]]
}

@test "skills validate passes on current primitives" {
  command -v apm >/dev/null 2>&1 || skip "apm not on PATH"
  run env usage_cmd=validate ./.mise/tasks/skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"validated successfully"* ]]
}

@test "convention gate fails on Force Tags prescription" {
  tmp="$(mktemp -d)"
  cp -R .apm "$tmp/.apm"
  printf -- '- Use `Force Tags    smoke` on every suite.\n' >> "$tmp/.apm/instructions/rfhub-tag-placement.instructions.md"
  cd "$tmp"
  run "$PROJECT_ROOT/scripts/check-conventions.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no-force-tags"* ]]
  rm -rf "$tmp"
}

@test "convention gate allows teaching mentions of Force Tags" {
  tmp="$(mktemp -d)"
  cp -R .apm "$tmp/.apm"
  printf -- '- Do not use `Force Tags`; use Test Tags instead.\n' >> "$tmp/.apm/instructions/rfhub-tag-placement.instructions.md"
  cd "$tmp"
  run "$PROJECT_ROOT/scripts/check-conventions.sh"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "convention gate fails on VAR scope=TEST prescription" {
  tmp="$(mktemp -d)"
  cp -R .apm "$tmp/.apm"
  printf -- '- Hand off values with `VAR    ${x}    scope=TEST` in each case.\n' >> "$tmp/.apm/instructions/rfhub-gherkin.instructions.md"
  cd "$tmp"
  run "$PROJECT_ROOT/scripts/check-conventions.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no-var-scope-test"* ]]
  rm -rf "$tmp"
}
