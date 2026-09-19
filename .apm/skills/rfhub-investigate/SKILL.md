---
name: rfhub-investigate
description: >-
  Use when investigating Robot Framework Hub failures, flake, watchlist,
  duration regression, a specific run/test log, an acceptance report verdict,
  or mid-run live fails while a batch is still executing, or when classifying what kind of fault it is:
  faulty implementation, unclear plan, feature drift, faulty test logic,
  faulty test environment, or faulty harness. Apply when the user says "what
  failed", "why did this test fail", "is it flaky", "metrics", "attachments
  for this run", "new fail from the live stream", "is it the test, the code,
  or the environment", "acceptance report verdict", or "classify this failure". Prefer rfhub_failures /
  rfhub_run_log / rfhub_metrics_* over scraping log.html. Does not activate
  for writing or rewriting .robot sources (use rfhub-write-*) or for
  first-time MCP setup.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.4"
---
# rfhub-investigate

> **Access requirement:** reads results through a hub you are authorized on
> (log in via MCP OAuth, or use an API key for HTTP). Non-functional without
> hub access. See the package README, "Access requirements".

Read results through hub MCP. Compact first; HTML artifacts last.

## When to use

- What failed / same error elsewhere (`q`)
- Why this test (excerpt + attachments)
- Flake, consecutive fails, duration, watchlist, project trend
- A **new** fail from mid-run feed (`rfhub_watch` / `since` / SSE) while the batch is still running
- **Classify the fault**: implementation, plan, drift, test logic, environment, or harness
- An acceptance run's verdict: which wave failed and whether the criteria still hold

## Instructions

1. Scope with `project` (UUID or display name). Optional `from` / `to` (`-24h`, `-7d`). Runs/jobs carry an `environment` (`dev` / `accpt` / `prod`); when a project has several, read that field so you compare like with like — `GET /api/agent/environments?project=…` lists a project’s envs and their `excludeTags`.
2. **What failed?** `rfhub_failures` (`compact` default true). Follow `runId` + `test_id`. For one live batch: `rfhub_failures({ runId, since })` or `rfhub_batch` `progress.newFails`.
3. **Why this test?** `rfhub_run` digest, then `rfhub_run_log` with `test=`. Use `attachments[]` / `attachmentHint` — do not open executor host paths. Download via hub attachment URLs only if the excerpt is not enough. Mid-run: message may be present from the listener; screenshots/traces often appear only after part XML ingest.
4. **Flaky / trend?** `rfhub_metrics_overview` → `rfhub_metrics_watchlist` → `rfhub_metrics_test` / `rfhub_metrics_suite` (`flips`, `repeatingErrors`, `durationStats`). `rfhub_test` / `rfhub_suite` if QuestDB `source` is unavailable. Prefer this before rewriting a mid-run fail.
5. **Live?** `rfhub_live` (or run live). Idle / no-listener hint means the runner never POSTed live events. Long batches: `rfhub_watch` for stream URL / poll recipe (see **rfhub-queue** fix-while-running).
6. Keep `limit` small. Only fetch `rfhub_run_test` / artifacts when excerpts are insufficient.
7. To change sources after diagnosis, switch to the matching **rfhub-write-*** skill. To re-run failed leaves into the **same** batch handle, use **rfhub-queue**’s rerun path (`rfhub_rerun` then poll `rfhub_batch`) — do not open a new `rfhub_queue` for a join. Do not `rfhub_rerun` mid-leaf while that part is still executing.

## Acceptance groups (report verdict before run detail)

When a run belongs to an acceptance group (`acceptanceGroupId` on the run digest, or a `groupId` from **rfhub-queue**'s acceptance run), open the auto-created acceptance **report** first — not just the run:

1. Poll `rfhub_acceptance_run({ groupId })` until `status` is `merged`, then read `report.verdict` (`passed` / `failed`). `status` is the merge lifecycle; `verdict` is the criteria outcome.
2. **Full acceptance can fail** — failed wave runs are allowed into the report. A `failed` verdict is recorded evidence, not a harness error. Name which wave(s) failed and what they ran (`gitSha` is the same commit on every wave batch).
3. Only then drill into the failing wave's batch with the normal ladder above (`rfhub_failures` → `rfhub_run_log` → classify the fault). A wave failure classifies like any batch failure.
4. A green report (`verdict: passed`) is release proof — quote the report id and `gitSha`. Do not rebuild the verdict by hand from wave runs; the report is canonical.
5. **Name evidence correctly.** A focused leaf/case run is not an acceptance report. A single `runId` digest is a run record. Do not narrate either as “acceptance passed” or as a substitute for a failed/blocked gate.
6. **Infra / harness blockers stay blockers.** If the acceptance gate cannot run or fails with process-shaped errors (network unreachable / `URLError`, no orchestrator, parts never uploaded, same infra error across unrelated waves), classify **faulty harness** or **faulty test environment** and **escalate**. Do not advise switching to focused-run greens or a handmade report as alternate acceptance proof — that is a false confidence path. Report via **rfhub-feedback** when the hub/orch is at fault.

## Classify the fault

Before any fix decision, name the fault class. Six classes: **faulty implementation**, **unclear plan**, **feature drift**, **faulty test logic**, **faulty test environment**, **faulty harness**. Gather evidence on this ladder — cheap rungs first, stop when one class dominates:

1. **Test history** — `rfhub_metrics_test` (`series`, `flips`, `consecutiveFails`, `repeatingErrors`, `durationStats`) and `rfhub_suite` history. Never passed anywhere → suspect the test. Passed yesterday, fails today → suspect what changed. Flips without source change → suspect environment or timing.
2. **Suite diff against main** — `git diff main...HEAD` on the failing leaf plus the keywords/resources it imports. Changed test/keyword + unchanged product → suspect test logic. Unchanged suite + product moved → suspect implementation.
3. **Git history on main** — when the test last changed on `main`, when it last passed (a passing run's `gitSha` via `rfhub_runs`), and the commits in between. This pins *which* change broke it.
4. **Current issue + past issues** — the issue that ordered this work (acceptance criteria vs test expectation vs implementation), and history: same `test_id` or same error fingerprint reported before (known flaky, known bug, known env incident).
5. **SUT state** — the run's `environment` (and its `excludeTags` — a selection change can fake a regression), SUT reachability/health, and that the deployed version matches what the run claims to test. **Feature flags**: if the SUT gates code paths behind flags, resolve the flag state for the failing codepath first — a feature that is toggled off is not broken, and blaming implementation before checking flags is the most common false verdict.
6. **rfhub / harness state** — infra-shaped shapes: executor crash or timeout before the test starts, live "no-listener" hint, attachments that never arrive, `source: "unavailable"`, the same infra error across unrelated leaves. Test-result-shaped failures are the SUT's problem; process-shaped failures are the hub's.

Full decision table with signal → verdict mappings: [references/classification.md](references/classification.md).

Ambiguity rule: two classes still fit after the full ladder → say both with the evidence for each and let the human decide. If the plan/acceptance criteria themselves are the contradiction, that **is** the verdict (`unclear plan`) — do not pick a side.

Field notes: [references/metrics.md](references/metrics.md).

## Gotchas

- `output.xml` is canonical. Do not iframe Robot `log.html` as the primary viewer.
- Compact mode shortens `firstError`; set `compact: false` only when you need the raw message.
- Metrics need QuestDB on the hub. `source: "unavailable"` is not “the test is fine”.
- Live fails are early signal; confirm after XML/rebot when deciding the batch is green.
- Different `environment`s apply different `excludeTags`, so a pass-rate or test-count shift can be a selection change, not a regression. Read `environment` before blaming code.
- Never reframe a failed or unreachable acceptance gate as green because some other focused suite passed on the same branch — escalate the gate/infra failure instead.
