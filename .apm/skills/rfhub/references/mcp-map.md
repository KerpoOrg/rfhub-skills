# MCP map (suite-repo agents)

Do not scrape the hub UI. Call these tools (same payloads as `{HUB_URL}/api/agent`). Full contract: hub repo `docs/AGENT-API.md`.

Keep results small: `limit`, then detail only failing ids.

| Intent | Tools |
|--------|--------|
| Discover | `rfhub_catalog`, `rfhub_projects` |
| Queue | `rfhub_queue` (`project`, `branch`, `suiteIds` and/or `tag` / `wave` / `all`, optional `parallelism` / `environment`, **`gitSha` required** for commit-bound evidence) → track with `rfhub_stream` (cursor loop until `closed: true`); poll `rfhub_batch` only as fallback or when explicitly asked |
| Mid-run fails (fix while running) | **`rfhub_stream` (primary)**: `rfhub_stream({ runId: handle, since })` cursor loop, act on each event immediately. Poll `rfhub_batch` / `rfhub_live` / `rfhub_failures` with `since` only as fallback (stream error / explicit ask); `rfhub_watch` SSE URL is for external HTTP clients |
| Release preflight | `rfhub_acceptance_gate` (`project`, `gitSha`, optional `suiteIds` / `tag` / `all` / `maxAge`) |
| Acceptance report (multi-run rebot) | `rfhub_acceptance_report_create` (`runIds` ≥2, same project+gitSha) → poll `rfhub_acceptance_report`; list with `rfhub_acceptance_reports` |
| Acceptance definitions (ordered waves as criteria) | Agent API `GET` / `PUT` / `DELETE /api/agent/acceptances` via **rfhub-write-acceptance** (no MCP tools — ordered wave ids, slugs resolved on save) |
| Run acceptance (definition order, one env, one commit) | `rfhub_acceptance_run` (`project`, `branch`, `environment`, `gitSha` — all required) → poll with `groupId` until `status=merged` → read `report.verdict` |
| Rerun failed / missing parts (same handle) | `rfhub_rerun` (`runId`, optional `suiteIds`; default = failed leaves ∪ pending parts) → `mode=rerun` + `units` + `overlay`; poll **same** handle with `rfhub_batch` (`parts.pending`, `progress.recovered`). Do not open a new `rfhub_queue` to join. |
| WIP without file tags | `rfhub_tag_set` / `rfhub_tags` / `rfhub_tag_clear` then queue with `tag` |
| Shared-fixture locks | No MCP tools — agent API + UI via **rfhub-use-locks** (`PUT /api/agent/lock-domains`, `PUT /api/agent/locks`, `GET /api/locks`, Live locks view) |
| Live | `rfhub_live` (optional `runId`, `since`) |
| What failed | `rfhub_failures` (`project`, optional `q`, optional `runId` + `since`) |
| Why this test | `rfhub_run`, `rfhub_run_log` (`test=`), `rfhub_run_test` |
| History / flake | `rfhub_test`, `rfhub_suite` |
| Trends | `rfhub_metrics_overview`, `rfhub_metrics_watchlist`, `rfhub_metrics_test`, `rfhub_metrics_suite` |

`rfhub_run` / `rfhub_run_log` include `attachments[]` when FAIL text matches uploads. Prefer that over `log.html`.

Queue needs an **online** orchestrator for that `project` + `branch`. Optional `worktree`, or `environment`, when more than one orch matches.

`wave` (slug) expands a project bundle of include tags + its `parallelism` (`serial` / `suite` (default) / `testcase`); `parallelism` can override it on any selection. `environment` co-selects the orchestrator that serves that env (`dev` / `accpt` / `prod`), stamps the run, and the runtime appends the env’s `excludeTags`. No MCP tools for these — manage via the agent API: `GET` / `PUT` / `DELETE /api/agent/waves` and `/api/agent/environments` (`?project=<id|name>`), or hub **Settings** (project → Waves / Environments). Runs carry `environment`.

**Skills + MCP ship together:** recipes live in `rfhub-queue` / `rfhub-investigate`; tools are `rfhub_*`. Consumers pin `rfhub-skills/vX.Y.Z` and install MCP for the same hub — do not teach queue without `gitSha` or report-create without the matching skill steps.

Send `X-Rfhub-Skills-Version: <semver>` on MCP HTTP requests. Hub `initialize` / `tools/list` `_meta` and `instructions` warn when the pin is missing or behind so agents can bump skills.
