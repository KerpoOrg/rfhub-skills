---
name: rfhub-queue
description: >-
  Use when queueing Robot suites on Robot Framework Hub, Play-from-hub,
  rfhub_queue (always pass gitSha for commit-bound evidence), polling a batch
  handle, watching mid-run failures (rfhub_watch / since cursors) to fix while a
  long batch still runs, marking WIP with rfhub_tag_set then queueing by tag,
  creating acceptance reports (rfhub_acceptance_report_create) from ≥2 passed
  runs that share projectId+gitSha, or rerunning failed leaves into the same
  handle with rfhub_rerun. Apply when the user says "run this suite", "queue
  smoke", "all: true", "play from the hub", "fix while tests are running",
  "create acceptance report", or "rerun failed into this run". Does not activate
  for writing .robot files alone, investigating past failures alone, or running
  Robot inside Next.js.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.2"
---
# rfhub-queue

> **Access requirement:** queueing runs through a hub you are authorized on
> (log in via MCP OAuth, or use an API key for HTTP). Non-functional without
> hub access. See the package README, "Access requirements".

Queue work to an **online** orchestrator for `project` + `branch`. Selection is an unordered set of suite ids; the orch schedules leaves with online LPT.

## When to use

- “Run / play / queue these suites on the hub”
- Poll status of a returned `handle` (`runId`)
- Fix failures **while** a multi-hour batch is still running
- Create an **acceptance report** from ≥2 passed runs for one commit
- Queue WIP via Redis marks (usually the whole suite) instead of committing `Force Tags    wip`

## Instructions

1. If MCP is down, use **rfhub-connect** first.
2. Resolve `project` (`project_id` UUID or configured name) and git `branch`. Optional `worktree` if more than one orch matches.
3. Confirm an orchestrator is online for that pair (`rfhub_projects` / live orch UI). Queue fails without one.
4. Choose selection (do **not** preserve array order):

   - Concrete leaves or parents: `suiteIds` as catalog `suite_id` UUIDs or longnames (`Synthetic.Smoke.Health`).
   - Whole catalog: `all: true`.
   - Label: `tag` (e.g. `wip`) — union of catalog static tags and Redis marks. Prefer `rfhub_tag_set` over committing `wip` file tags. Mark the **suite** (`kind: suite`, catalog `suite_id`): cases in a leaf are usually interdependent. Mark `kind: test` only when the suite is partially WIP. Do **not** use Robot `--include wip` for Redis marks (the tag is not in the `.robot` file).

5. Call `rfhub_queue`. **Always pass `gitSha`** (`git rev-parse HEAD` of the suite worktree you are validating). Without it the run cannot prove a commit for `rfhub_acceptance_gate` or **acceptance reports** (UI shows `no commit`; create refuses). Response `handle` is the batch `runId`.
6. Track progress:

   - Short batches: poll `rfhub_batch` for `jobStatus`, parts, live counts. `rfhub_live` for in-progress tests.
   - Long batches (fix-while-running): call `rfhub_watch({ runId: handle })` for the Bearer SSE URL, **or** poll with a `since` cursor (below).

7. When the batch finishes with failures → **rfhub-investigate**, then **rerun into the same handle** (below). Do not rewrite sources in the investigate skill itself.
8. When several wave/leaf batches for the **same** `project` + `gitSha` are green → **Acceptance reports** (below).

### Acceptance reports (multi-run evidence)

Skills are the recipe; MCP tools are the verbs. After ≥2 **passed** runs share `projectId` + `gitSha` (each with `output.xml`):

1. Collect their `runId`s (`rfhub_runs` filtered by `project` + `gitSha` + `status=passed`, or the handles you just polled).
2. `rfhub_acceptance_report_create({ runIds: […] })` — order is display/merge order; minimum 2.
3. Poll `rfhub_acceptance_report({ id })` until `status` is `ready` (or `failed`).
4. Optional list: `rfhub_acceptance_reports({ project, gitSha })`.

UI: Collected runs → select matching commits → **Create acceptance report**. The Run column is a **run id**, not the commit — rows show `git:…` / `no commit` in the suite stack. Do not select mixed commits or runs without `gitSha`.

**Agent mistake to avoid:** queueing without `gitSha` (or omitting it on Play). Those runs never become acceptance-report sources even if they are green.

### Fix while running (mid-run fail feed)

1. Keep `handle` from `rfhub_queue`. Start `since = 0` (or `rfhub_watch`’s returned `since`).
2. Prefer poll in Cursor: `rfhub_batch({ handle, since })` → read `progress.newFails` / `progress.failSeq`, or `rfhub_live` / `rfhub_failures` with `runId` + `since`. Bump `since` to `failSeq` / `cursor` after each poll. Do **not** hold one MCP tool call open for hours.
3. On each **new** fail: dedupe by `testId` / `robotId`. Quick flake check with `rfhub_metrics_test` before rewriting flaky cases.
4. Investigate (`rfhub_run_log` / **rfhub-investigate**) — live `message` may exist; attachments often wait for part XML.
5. Edit suite sources in the suite worktree (`rfhub-write-*`). Optionally `rfhub_tag_set` `wip` on the leaf under edit.
6. Do **not** `rfhub_rerun` until that leaf/part is idle or the whole batch finishes (overlay still joins the same handle).
7. After the batch (or settled leaves): **rerun into the same handle** below.

External agents that can hold HTTP may `GET /api/agent/runs/{handle}/failures/stream` with Bearer + `Accept: text/event-stream` (reconnect with `since` / `Last-Event-ID`).

### Rerun failed into the same handle

1. Prefer leaf `suite_id` UUIDs from failures (or omit `suiteIds` to rerun failed leaves **and** pending/never-uploaded parts).
2. Call `rfhub_rerun({ runId: handle })`. Read echoed `units` / `overlay.parts` — that is exactly what will execute.
3. Poll `rfhub_batch` with the **same** handle until `parts.pending` is empty. `progress.recovered` counts fail→pass on this join.
4. Do **not** call `rfhub_queue` again to join results; that is a new batch.

WIP mark/list/clear shapes: [references/queue.md](references/queue.md).

## Gotchas

- **Always pass `gitSha` on `rfhub_queue`** when the run may feed release preflight or acceptance reports. Omitting it is a consumer bug — the hub cannot invent the commit later from the Run column (that column is the run id).
- Parents expand to leaves on the hub. Queueing a parent is enough; do not also list every child unless you want a subset.
- Marking every test in a leaf `wip` is almost always wrong — mark the suite instead.
- `OUT_DIR/rfhub.args` is **generated by the runner** per executor. Do not use a consumer argument file as a substitute for `suiteIds`.
- Orchestrator runs **one queued batch at a time**; later jobs stay queued.
- Do not invent `RUN_ID` for Play-from-hub — the queue response is the id.
- Rerun keeps the handle; a second `rfhub_queue` does not overlay the first run.
- Mid-run fixes do not change executors already running; use `rfhub_rerun` to overlay after.
- Acceptance reports need the **same** `projectId` + `gitSha` on every source run; mixed commits or `no commit` runs are rejected.
