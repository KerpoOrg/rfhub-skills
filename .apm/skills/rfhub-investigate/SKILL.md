---
name: rfhub-investigate
description: >-
  Use when investigating Robot Framework Hub failures, flake, watchlist,
  duration regression, a specific run/test log, or mid-run live fails while a
  batch is still executing. Apply when the user says "what failed", "why did
  this test fail", "is it flaky", "metrics", "attachments for this run", or
  "new fail from the live stream". Prefer rfhub_failures / rfhub_run_log /
  rfhub_metrics_* over scraping log.html. Does not activate for writing or
  rewriting .robot sources (use rfhub-write-*) or for first-time MCP setup.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.1"
---
# rfhub-investigate

> **Access requirement:** reads results through a hub you are authorized on and
> requires a Bearer access key. Non-functional without hub access. See the
> package README, "Access requirements".

Read results through hub MCP. Compact first; HTML artifacts last.

## When to use

- What failed / same error elsewhere (`q`)
- Why this test (excerpt + attachments)
- Flake, consecutive fails, duration, watchlist, project trend
- A **new** fail from mid-run feed (`rfhub_watch` / `since` / SSE) while the batch is still running

## Instructions

1. Scope with `project` (UUID or display name). Optional `from` / `to` (`-24h`, `-7d`).
2. **What failed?** `rfhub_failures` (`compact` default true). Follow `runId` + `test_id`. For one live batch: `rfhub_failures({ runId, since })` or `rfhub_batch` `progress.newFails`.
3. **Why this test?** `rfhub_run` digest, then `rfhub_run_log` with `test=`. Use `attachments[]` / `attachmentHint` — do not open executor host paths. Download via hub attachment URLs only if the excerpt is not enough. Mid-run: message may be present from the listener; screenshots/traces often appear only after part XML ingest.
4. **Flaky / trend?** `rfhub_metrics_overview` → `rfhub_metrics_watchlist` → `rfhub_metrics_test` / `rfhub_metrics_suite` (`flips`, `repeatingErrors`, `durationStats`). `rfhub_test` / `rfhub_suite` if QuestDB `source` is unavailable. Prefer this before rewriting a mid-run fail.
5. **Live?** `rfhub_live` (or run live). Idle / no-listener hint means the runner never POSTed live events. Long batches: `rfhub_watch` for stream URL / poll recipe (see **rfhub-queue** fix-while-running).
6. Keep `limit` small. Only fetch `rfhub_run_test` / artifacts when excerpts are insufficient.
7. To change sources after diagnosis, switch to the matching **rfhub-write-*** skill. To re-run failed leaves into the **same** batch handle, use **rfhub-queue**’s rerun path (`rfhub_rerun` then poll `rfhub_batch`) — do not open a new `rfhub_queue` for a join. Do not `rfhub_rerun` mid-leaf while that part is still executing.

Field notes: [references/metrics.md](references/metrics.md).

## Gotchas

- `output.xml` is canonical. Do not iframe Robot `log.html` as the primary viewer.
- Compact mode shortens `firstError`; set `compact: false` only when you need the raw message.
- Metrics need QuestDB on the hub. `source: "unavailable"` is not “the test is fine”.
- Live fails are early signal; confirm after XML/rebot when deciding the batch is green.
