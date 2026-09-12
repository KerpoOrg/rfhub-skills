---
name: rfhub
description: >-
  Use when working with Robot Framework Hub, RF Hub, rfhub, MCP rfhub_* tools,
  queueing suites, investigating failures or flake, or writing hub-compatible
  Robot sources. Apply when the user mentions the hub but has not named a
  sub-skill. Routes to rfhub-connect, rfhub-queue, rfhub-investigate, rfhub-feedback,
  or a rfhub-write-* skill. Does not activate for hub product internals (apps/web,
  Helm, Prisma) — that is AGENTS.md in the hub repo.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub

> **Access requirement:** hub-facing skills (`rfhub-connect`, `rfhub-queue`,
> `rfhub-investigate`, `rfhub-feedback`) need a running hub URL and a Bearer
> access key. Without hub access only the `rfhub-write-*` skills and the
> always-on instructions are useful. See the package README, "Access
> requirements".

Map skill for **consuming** Robot Framework Hub from a suite repo. Prefer hub MCP over scraping the UI or Robot HTML.

## When to use

- User mentions RF Hub / rfhub / “the hub” without a specific workflow
- Unclear whether to queue, debug a run, or edit `.robot` files
- First contact: “what can the hub do?”

## Instructions

1. Confirm this is a **suite repo** (`.robot` / orchestrator consumer), not hub product development. Hub internals stay in that repo’s `AGENTS.md`.
2. If MCP `rf-hub` tools are missing, follow **rfhub-connect** first.
3. Route:

| User intent | Skill |
|-------------|--------|
| Wire MCP / access key / “not connected” | `rfhub-connect` |
| Run / play / queue suites, WIP tag, fix-while-running / mid-run fails, **acceptance reports** | `rfhub-queue` |
| What failed, why, flake, watchlist, metrics, mid-run live fail | `rfhub-investigate` |
| Bug / feature / feedback on hub, orch, skills, runner | `rfhub-feedback` |
| Robot `*.args` / `--argumentfile` | `rfhub-write-argumentfile` |
| New folder / `__init__.robot` / leaf suite | `rfhub-write-suite` |
| Add or change a test case | `rfhub-write-testcase` |
| Keyword in the same `.robot` as the tests | `rfhub-write-suitekeyword` |
| Shared keyword in `*.resource` | `rfhub-write-resourcekeyword` |
| Python library keyword | `rfhub-write-pythonkeyword` |

4. Always-on file rules (Cursor `.mdc` / Claude rules) already cover identity tags, tag placement (promote/demote, suite-level WIP), Gherkin cases, leaf layout, and FAIL attachment paths. Do not contradict them.
5. Do not run Robot inside Next.js. Do not iframe `log.html` as the primary report. `output.xml` is canonical.

MCP tool names and compact use-cases: [references/mcp-map.md](references/mcp-map.md).

## Gotchas

- `suiteIds` is an unordered set; LPT schedules leaves. Array order is not a run order.
- Identity tags (`project_id:`, `suite_id:`, `test_id:`) must stay stable across renames.
- Do not declare hub MCP as a static APM `mcp:` dependency — URL and Bearer are per environment.
