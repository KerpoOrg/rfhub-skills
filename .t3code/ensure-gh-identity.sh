#!/usr/bin/env bash
# GitHub identity guard for this repo. Installed by kerpo-t3code-setup.
#
# The expected GitHub account is pinned per repo with:
#   git config t3code.ghAccount <login>
# The setting lives in the shared .git/config, so every linked worktree of
# this repo (including T3 Code session worktrees) reads the same account.
# T3 Code runs this script on worktree create via t3.json.
set -euo pipefail

FIX="false"

for arg in "$@"; do
  case "$arg" in
    --fix) FIX="true" ;;
    -h|--help)
      echo "Usage: .t3code/ensure-gh-identity.sh [--fix]"
      echo "  (default) Verify gh's active GitHub account matches this repo's pinned account."
      echo "  --fix     Switch the active account to the pinned account when it differs."
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found on PATH. Install it (e.g. brew install gh) and run: gh auth login" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run this script from inside the repository." >&2
  exit 1
fi

EXPECTED_LOGIN="$(git config t3code.ghAccount || true)"

if [[ -z "$EXPECTED_LOGIN" ]]; then
  echo "Error: no pinned GitHub account for this repo. Run the kerpo-t3code-setup skill," >&2
  echo "or set it manually: git config t3code.ghAccount <login>" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi

current_login="$(gh api user --jq .login 2>/dev/null || true)"

if [[ "$current_login" == "$EXPECTED_LOGIN" ]]; then
  echo "GitHub identity ok: ${EXPECTED_LOGIN}"
  exit 0
fi

if [[ "$FIX" != "true" ]]; then
  echo "Error: gh's active account is '${current_login:-unknown}', expected '${EXPECTED_LOGIN}'." >&2
  echo "Run: gh auth switch --user ${EXPECTED_LOGIN}" >&2
  echo "Or: $0 --fix" >&2
  exit 1
fi

if ! gh auth status 2>/dev/null | grep -q "account ${EXPECTED_LOGIN}"; then
  echo "Error: '${EXPECTED_LOGIN}' is not logged in to gh. Run: gh auth login" >&2
  exit 1
fi

gh auth switch --user "$EXPECTED_LOGIN" >/dev/null
current_login="$(gh api user --jq .login 2>/dev/null || true)"

if [[ "$current_login" != "$EXPECTED_LOGIN" ]]; then
  echo "Error: failed to switch gh's active account to '${EXPECTED_LOGIN}'." >&2
  exit 1
fi

echo "Switched gh's active account to ${EXPECTED_LOGIN}"
