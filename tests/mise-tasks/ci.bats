#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  cd "$PROJECT_ROOT"
  # Parent `mise run ci -- test` exports usage_cmd=test; clear so direct script
  # invocations under bats do not re-enter cmd_test (infinite bats recursion).
  unset usage_cmd usage_yes || true
}

@test "ci USAGE declares lint and test" {
  run grep -E '^#USAGE cmd "' .mise/tasks/ci
  [ "$status" -eq 0 ]
  [[ "$output" == *'cmd "lint"'* ]]
  [[ "$output" == *'cmd "test"'* ]]
}

@test "ci without subcommand prints brief usage" {
  run env -u usage_cmd -u usage_yes ./.mise/tasks/ci
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: mise run ci"* ]]
  [[ "$output" == *"lint"* ]]
  [[ "$output" == *"test"* ]]
}

@test "ci lint passes shellcheck" {
  run env usage_cmd=lint ./.mise/tasks/ci
  [ "$status" -eq 0 ]
  [[ "$output" == *"shellcheck ok"* ]]
}
