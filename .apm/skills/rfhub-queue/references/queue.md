# Queue, WIP tags, and acceptance reports

```json
POST /api/agent/queue
{
  "project": "3682ae73-3b51-4816-9a39-21fbda91d28f",
  "branch": "main",
  "suiteIds": ["c7b9a683-fb3a-4513-85fd-38a9d60e7c00"],
  "gitSha": "abcdef0123456789abcdef0123456789abcdef01"
}
```

MCP: `rfhub_queue` with the same fields. **Pass `gitSha` every time** (`git rev-parse HEAD` in the suite worktree). Track with `rfhub_stream({ runId: handle, since })` — cursor loop until `closed: true`; poll `rfhub_batch` only as fallback or when explicitly asked.

Without `gitSha`, the run cannot:

- satisfy `rfhub_acceptance_gate` for that commit
- be selected into an **acceptance report** (UI shows `no commit`)

The response echoes a per-unit `locks` array, e.g. `"locks":[{"domain":"txn","name":"yes","count":1}]`. That is **tag parsing only** — the `domain:name[:count]` tags found on the selection — not evidence a lock was acquired. Acquisition only happens for domains declared via `PUT /api/agent/lock-domains` (see **rfhub-use-locks**); check `GET /api/agent/locks` for real holders/waiters before treating units as serialized.

## Waves and environments

Queue a project wave by slug (preferred for recurring bundles). `parallelism` overrides the wave; `environment` picks the orchestrator and stamps the run:

```json
POST /api/agent/queue
{
  "project": "3682ae73-3b51-4816-9a39-21fbda91d28f",
  "branch": "main",
  "wave": "smoke",
  "parallelism": "suite",
  "environment": "dev",
  "gitSha": "abcdef0123456789abcdef0123456789abcdef01"
}
```

- `wave` ∪ `tag`/`tags`, ∩ `suiteIds`. `includeTags` resolve like `tag` (catalog static ∪ Redis).
- `parallelism`: `serial` | `suite` (default) | `testcase`; `testcase` = one executor per test, bounded by `EXECUTOR_PARALLEL`.
- `environment` is required when several orchestrators serve the same `project` + `branch` (else `409`); the runtime appends that environment's `excludeTags` last.

Wave CRUD:

```http
GET    /api/agent/waves?project=<id|name>          → { waves: [ … ] }
PUT    /api/agent/waves  { project, slug, title, description?, includeTags?, parallelism? }
DELETE /api/agent/waves?project=<id|name>&slug=<slug>
```

Environment CRUD (`excludeTags` is a list or newline-separated string, one expression per line):

```http
GET    /api/agent/environments?project=<id|name>   → { environments: [ … ] }
PUT    /api/agent/environments  { project, slug, title, description?, excludeTags? }
DELETE /api/agent/environments?project=<id|name>&slug=<slug>
```

Runs (and `rfhub_runs` / run digests) carry the `environment` that produced them.

## Acceptance reports

After ≥2 passed runs share `projectId` + `gitSha`:

```json
POST /api/agent/acceptance-reports
{ "runIds": ["<run-a>", "<run-b>"] }
```

MCP: `rfhub_acceptance_report_create` → poll `rfhub_acceptance_report` until `ready`.

## Running acceptance (definition order, one environment, one commit)

Discover the project's definition(s) first — do not assume the default slug:

```http
GET /api/agent/acceptances?project=<id|name>   → definition(s) with their slug and ordered waves
```

A project may have more than one named definition (e.g. default `acceptance` for release preflight, `pr` for a PR-triggered gate). Check the suite repo's own guidance for the slug it expects before running.

```json
POST /api/agent/acceptance-runs
{
  "project": "3682ae73-3b51-4816-9a39-21fbda91d28f",
  "branch": "main",
  "environment": "accpt",
  "gitSha": "abcdef0123456789abcdef0123456789abcdef01",
  "acceptance": "pr"
}
```

MCP: `rfhub_acceptance_run` with the same fields (`project`, `branch`, `environment`, `gitSha` required; `acceptance` optional, defaults to `"acceptance"`) → returns a `groupId` → poll `rfhub_acceptance_run({ groupId })` (or `GET /api/agent/acceptance-runs?groupId=…`) until `status` is `merged` → read `report.verdict` (`passed` / `failed`).

- The project's acceptance definition (**rfhub-write-acceptance**) supplies the ordered waves; waves run one batch at a time in definition order on that one environment. No definition yet? Author it with that skill first — definition CRUD has no MCP verbs, only `GET` / `PUT` / `DELETE /api/agent/acceptances`; an empty `acceptances: []` is a common greenfield state.
- Local **WIP** dogfood is offline: `rfhub batch "<Project>" wip ./suites` (≡ `acceptance:wip`) against the SUT — **not** this orch acceptance-run path.
- **`pr` / `release`:** use this orch acceptance-run path by default. Offline `rfhub batch … pr|release` only for chicken/egg or when the human asks.
- A definition whose waves use Redis marks needs matching `rfhub_tag_set` labels (often `wave:wip`) before orch will select those leaves. Empty match means fix the marks/slug, not fall back to a hand-picked wave or suite list.
- `status` is the merge lifecycle; `verdict` is the criteria outcome. Full acceptance can fail — failed wave runs are allowed into the auto-created report.
- A green report is release proof (`rfhub_acceptance_gate` counts it for the default criteria).
- Commits are never mixed: every wave batch carries the same `gitSha`.

## Rerun failed (same handle)

```json
POST /api/agent/runs/{runId}/rerun
{ "suiteIds": ["optional-leaf-suite-uuid"] }
```

MCP: `rfhub_rerun`. Response includes `mode: "rerun"`, `overlay.parts`, and `units` (exact leaves). Track the same `handle` with `rfhub_stream` (cursor loop until `closed: true`); poll `rfhub_batch` (`parts.pending`, `progress.recovered`) as fallback. Do not open a new queue to join.

## Redis WIP marks

Marks live in hub Redis (default TTL 7 days). Identity prefixes (`project_id`, `suite_id`, `test_id`, `exec_host_id`) are rejected as tag names. Do **not** commit suite tags for ephemeral WIP.

Prefer `kind: suite` and the leaf (or parent) `suite_id`. Cases in a suite are usually interdependent — do not mark each test unless the suite is only partially WIP.

- `rfhub_tag_set` — `project`, `branch`, `tag`, `kind` (`suite`|`test`), `id` (UUID)
- `rfhub_tags` — list union (catalog static + Redis) as a minimized selection (needs an orch catalog)
- `rfhub_tag_clear` — drop marks

The mark’s `tag` must match the wave / acceptance **include label** you will select (consumers often use `wave:wip`, not the bare word `wip`).

**Run local WIP:** `rfhub batch "<Project>" wip ./suites` — CLI passes checkout `branch`; batch-config expands matching Redis marks into identity `--include suite_id:` / `test_id:` (RFHUB-29). Unmarked allow-empty WIP waves still pass.

**Orch:** `rfhub_queue` with `tag: "wave:wip"` (and optional `suiteIds`) or a wave whose `includeTags` include that label.

Tag names: Robot labels with optional colon namespaces (`wave:wip`), stored lowercase.
