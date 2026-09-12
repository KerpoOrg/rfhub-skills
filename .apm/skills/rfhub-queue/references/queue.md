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

MCP: `rfhub_queue` with the same fields. **Pass `gitSha` every time** (`git rev-parse HEAD` in the suite worktree). Poll `rfhub_batch` with `handle`.

Without `gitSha`, the run cannot:

- satisfy `rfhub_acceptance_gate` for that commit
- be selected into an **acceptance report** (UI shows `no commit`)

## Acceptance reports

After ≥2 passed runs share `projectId` + `gitSha`:

```json
POST /api/agent/acceptance-reports
{ "runIds": ["<run-a>", "<run-b>"] }
```

MCP: `rfhub_acceptance_report_create` → poll `rfhub_acceptance_report` until `ready`.

## Rerun failed (same handle)

```json
POST /api/agent/runs/{runId}/rerun
{ "suiteIds": ["optional-leaf-suite-uuid"] }
```

MCP: `rfhub_rerun`. Response includes `mode: "rerun"`, `overlay.parts`, and `units` (exact leaves). Poll the **same** `handle` with `rfhub_batch`. Do not open a new queue to join.

## Redis WIP marks

Marks live in hub Redis (default TTL 7 days). Identity prefixes (`project_id`, `suite_id`, `test_id`, `exec_host_id`) are rejected as tag names.

Prefer `kind: suite` and the leaf (or parent) `suite_id`. Cases in a suite are usually interdependent — do not mark each test unless the suite is only partially WIP.

- `rfhub_tag_set` — `project`, `branch`, `tag`, `kind` (`suite`|`test`), `id` (UUID)
- `rfhub_tags` — list union (catalog static + Redis) as a minimized selection
- `rfhub_tag_clear` — drop marks
- Then `rfhub_queue` with `tag: "wip"` (and optional extra `suiteIds`)

Tag names: `[a-zA-Z][a-zA-Z0-9_-]{0,63}`, stored lowercase.
