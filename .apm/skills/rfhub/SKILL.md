---
name: rfhub
description: >-
  Use when working with Robot Framework Hub, RF Hub, rfhub, MCP rfhub_* tools,
  queueing suites, investigating failures or flake, or writing hub-compatible
  Robot sources. Apply when the user mentions the hub but has not named a
  sub-skill. Routes to rfhub-connect, rfhub-queue, rfhub-investigate, rfhub-fixloop,
  rfhub-use-locks, rfhub-feedback,
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
> `rfhub-investigate`, `rfhub-feedback`) need a running hub URL and an account
> that can log in to it (MCP uses OAuth). Without hub access only the
> `rfhub-write-*` skills and the always-on instructions are useful. See the
> package README, "Access requirements".

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
| Wire MCP / OAuth login / “not connected” | `rfhub-connect` |
| Run / play / queue suites, project **waves** / **environments** / parallelism, WIP tag, fix-while-running / mid-run fails, **acceptance reports** | `rfhub-queue` |
| What failed, why, flake, watchlist, metrics, mid-run live fail | `rfhub-investigate` |
| Iteratively fix failures until green (diagnose → fix → rerun → re-check, with budget/stop rules) | `rfhub-fixloop` |
| Shared fixtures / lock domains / `domain:name[:count]` tags / scoped caps / Live locks view | `rfhub-use-locks` |
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
- Prefer a project **wave** (`wave=<slug>`) over re-specifying long tag/suite lists; `wave` ∪ `tag`, ∩ `suiteIds`.
- Pass `environment` when a project + branch has several orchestrators (`dev` / `accpt` / `prod`) — otherwise queue returns `409 Multiple orchestrators match`. The environment’s `excludeTags` are applied by the orchestrator at launch.
- Identity tags (`project_id:`, `suite_id:`, `test_id:`) must stay stable across renames.
- Do not declare hub MCP as a static APM `mcp:` dependency — the URL is per environment and MCP auth is OAuth (or a manually minted key).
