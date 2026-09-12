# MCP map (suite-repo agents)

Do not scrape the hub UI. Call these tools (same payloads as `{HUB_URL}/api/agent`). Full contract: hub repo `docs/AGENT-API.md`.

Keep results small: `limit`, then detail only failing ids.

| Intent | Tools |
|--------|--------|
| Discover | `rfhub_catalog`, `rfhub_projects` |
| Queue | `rfhub_queue` (`project`, `branch`, `suiteIds` and/or `tag` / `all`, **`gitSha` required** for commit-bound evidence) → poll `rfhub_batch` |
| Mid-run fails (fix while running) | `rfhub_watch` (SSE URL + poll recipe) or `rfhub_batch` / `rfhub_live` / `rfhub_failures` with `since`; bump to `failSeq` / `cursor` |
| Release preflight | `rfhub_acceptance_gate` (`project`, `gitSha`, optional `suiteIds` / `tag` / `all` / `maxAge`) |
| Acceptance report (multi-run rebot) | `rfhub_acceptance_report_create` (`runIds` ≥2, same project+gitSha) → poll `rfhub_acceptance_report`; list with `rfhub_acceptance_reports` |
| Rerun failed / missing parts (same handle) | `rfhub_rerun` (`runId`, optional `suiteIds`; default = failed leaves ∪ pending parts) → `mode=rerun` + `units` + `overlay`; poll **same** handle with `rfhub_batch` (`parts.pending`, `progress.recovered`). Do not open a new `rfhub_queue` to join. |
| WIP without file tags | `rfhub_tag_set` / `rfhub_tags` / `rfhub_tag_clear` then queue with `tag` |
| Live | `rfhub_live` (optional `runId`, `since`) |
| What failed | `rfhub_failures` (`project`, optional `q`, optional `runId` + `since`) |
| Why this test | `rfhub_run`, `rfhub_run_log` (`test=`), `rfhub_run_test` |
| History / flake | `rfhub_test`, `rfhub_suite` |
| Trends | `rfhub_metrics_overview`, `rfhub_metrics_watchlist`, `rfhub_metrics_test`, `rfhub_metrics_suite` |

`rfhub_run` / `rfhub_run_log` include `attachments[]` when FAIL text matches uploads. Prefer that over `log.html`.

Queue needs an **online** orchestrator for that `project` + `branch`. Optional `worktree` when more than one orch matches.

**Skills + MCP ship together:** recipes live in `rfhub-queue` / `rfhub-investigate`; tools are `rfhub_*`. Consumers pin `rfhub-skills/vX.Y.Z` and install MCP for the same hub — do not teach queue without `gitSha` or report-create without the matching skill steps.

Send `X-Rfhub-Skills-Version: <semver>` on MCP HTTP requests. Hub `initialize` / `tools/list` `_meta` and `instructions` warn when the pin is missing or behind so agents can bump skills.
