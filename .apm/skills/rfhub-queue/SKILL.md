---
name: rfhub-queue
description: >-
  Use when queueing Robot suites on Robot Framework Hub, Play-from-hub,
  rfhub_queue (always pass gitSha for commit-bound evidence), queueing a project
  wave (wave=) or a project environment (dev/accpt/prod), choosing parallelism
  (serial/suite/testcase), polling a batch handle, watching mid-run failures
  (rfhub_watch / since cursors) to fix while a long batch still runs, marking WIP
  with rfhub_tag_set then queueing by tag, creating acceptance reports
  (rfhub_acceptance_report_create) from ≥2 passed runs that share
  projectId+gitSha, or rerunning failed leaves into the same handle with
  rfhub_rerun. Apply when the user says "run this suite", "queue smoke", "queue
  the smoke wave", "run in dev / accpt / prod", "all: true", "play from the
  hub", "testcase parallelism", "fix while tests are running", "create
  acceptance report", or "rerun failed into this run". Does not activate for
  writing .robot files alone, investigating past failures alone, or running
  Robot inside Next.js.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.3"
---
# rfhub-queue

> **Access requirement:** queueing runs through a hub you are authorized on
> (log in via MCP OAuth, or use an API key for HTTP). Non-functional without
> hub access. See the package README, "Access requirements".

Queue work to an **online** orchestrator for `project` + `branch`. Selection is an unordered set of suite ids; the orch schedules leaves with online LPT.

## When to use

- “Run / play / queue these suites on the hub”
- “Queue the smoke / nightly **wave**” — a project-scoped reusable bundle
- “Run in dev / accpt / prod” — pick a project **environment** (and its exclusions)
- Poll status of a returned `handle` (`runId`)
- Fix failures **while** a multi-hour batch is still running
- Create an **acceptance report** from ≥2 passed runs for one commit
- Queue WIP via Redis marks (usually the whole suite) instead of committing `Test Tags    wip`

## Instructions

1. If MCP is down, use **rfhub-connect** first.
2. Resolve `project` (`project_id` UUID or configured name) and git `branch`. Optional `worktree`, or `environment`, if more than one orch matches.
3. Confirm an orchestrator is online for that pair (`rfhub_projects` / live orch UI). Queue fails without one.
4. Choose selection (do **not** preserve array order):

   - Concrete leaves or parents: `suiteIds` as catalog `suite_id` UUIDs or longnames (`Synthetic.Smoke.Health`).
   - Project **wave** (say “the smoke **wave**”): `wave: "smoke"` — a reusable bundle of include tags plus a scheduling `parallelism`. It is a **slug**, not a suite name. Preferred when the same selection is run repeatedly (CI, nightly). Unioned with `tag`/`tags`, intersected with `suiteIds`.
   - Whole catalog: `all: true`.
   - Label: `tag` (e.g. `wip`) — union of catalog static tags and Redis marks. Prefer `rfhub_tag_set` over committing `wip` file tags. Mark the **suite** (`kind: suite`, catalog `suite_id`): cases in a leaf are usually interdependent. Mark `kind: test` only when the suite is partially WIP. Do **not** use Robot `--include wip` for Redis marks (the tag is not in the `.robot` file).
   - Scheduling: `parallelism` (`serial` | `suite` | `testcase`, default `suite`) works on any selection and overrides the wave’s mode. Use `parallelism: "serial"` when units share a fixture — do **not** split the run into several queue calls.
   - Environment: `environment` (slug) — selects the orchestrator serving that environment and stamps the run; the orchestrator appends that environment’s `excludeTags` at launch. **Required** when several environments run the same `project`+`branch`.

5. Call `rfhub_queue`. **Always pass `gitSha`** (`git rev-parse HEAD` of the suite worktree you are validating). Without it the run cannot prove a commit for `rfhub_acceptance_gate` or **acceptance reports** (UI shows `no commit`; create refuses). Response `handle` is the batch `runId`.
6. Track progress:

   - Short batches: poll `rfhub_batch` for `jobStatus`, parts, live counts. `rfhub_live` for in-progress tests.
   - Long batches (fix-while-running): call `rfhub_watch({ runId: handle })` for the Bearer SSE URL, **or** poll with a `since` cursor (below).

7. When the batch finishes with failures → **rfhub-investigate**, then **rerun into the same handle** (below). Do not rewrite sources in the investigate skill itself.
8. When several wave/leaf batches for the **same** `project` + `gitSha` are green → **Acceptance reports** (below).

### Waves and parallelism

A **wave** is a project-scoped, named bundle of inclusion tags plus a scheduling granularity — the preferred way to request a recurring run. Queue it by slug and the hub expands the wave’s tags to a selection; the orchestrator still applies the environment’s exclusions.

- `rfhub_queue({ project, branch, wave: "smoke", gitSha })` — no long tag/suite list in the prompt.
- `includeTags` resolve like queue `tag`: catalog static tags ∪ Redis marks. A wave unions with `tag`/`tags` and intersects with `suiteIds`.
- `parallelism` (override): `serial` — one unit at a time (batch capped to one executor); `suite` (default) — leaf suites in parallel up to `EXECUTOR_PARALLEL`; `testcase` — one executor per test (hub expands each leaf into per-test units, still bounded by `EXECUTOR_PARALLEL`).
- Serial on an ad-hoc selection: `rfhub_queue({ project, branch, suiteIds: […], parallelism: "serial", gitSha })`. One queue call — the hub runs the units one at a time. Do **not** queue each leaf separately to serialize.
- Prefer a wave when the bundle is stable and shared (CI jobs, nightly regression); use ad-hoc `tag` / `suiteIds` for one-off cuts.
- CRUD lives on the hub API: `GET` / `PUT` / `DELETE /api/agent/waves` (`slug`, `title`, `description?`, non-empty `includeTags`, `parallelism`). Create/edit waves in the hub UI (project → Settings → Waves) or via that API; queue slugs must already exist.

### Environments

A project owns named **environments** (e.g. `dev`, `accpt`, `prod`), each with its own Robot `--exclude` tag expressions. An orchestrator registers the one environment it serves (`ENVIRONMENT`).

- Pass `environment` to `rfhub_queue` to select the orchestrator for that slug and stamp the run. Required when several environments serve the same `project`+`branch`; otherwise queue returns `409 Multiple orchestrators match` (`404` if no orchestrator registered for the slug).
- The runtime resolves the environment’s current `excludeTags` immediately before launch and appends them **last** to every unit — the same selection can run different tests per environment.
- `GET /api/agent/environments?project=…` lists them; `PUT` / `DELETE /api/agent/environments` manage (`slug`, `title`, `description?`, `excludeTags?`). Runs carry `environment`; read it on `rfhub_runs` / the run digest. Runtimes read `GET /api/orchestrators/{id}/environment`.

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
- **Select the `environment`** when a project + branch has more than one orchestrator; without it queue returns `409 Multiple orchestrators match`. The slug must exist under the project and an orchestrator must be registered for it (`404` otherwise).
- `wave` is a slug, not a tag or longname. Waves are project-scoped (no per-branch variant); `wave` ∪ `tag`, ∩ `suiteIds`. A missing slug is `404`.
- `testcase` fans out one executor per test (bounded by `EXECUTOR_PARALLEL`); `serial` caps the batch to a single executor at a time. Use it deliberately on shared fixtures.
- `OUT_DIR/rfhub.args` is **generated by the runner** per executor. Do not use a consumer argument file as a substitute for `suiteIds`.
- Orchestrator runs **one queued batch at a time**; later jobs stay queued. Within a batch, concurrency is set by `parallelism` (`serial` = one unit at a time) — do not split one run into several `rfhub_queue` calls to serialize it.
- Do not invent `RUN_ID` for Play-from-hub — the queue response is the id.
- Rerun keeps the handle; a second `rfhub_queue` does not overlay the first run.
- Mid-run fixes do not change executors already running; use `rfhub_rerun` to overlay after.
- Acceptance reports need the **same** `projectId` + `gitSha` on every source run; mixed commits or `no commit` runs are rejected.
