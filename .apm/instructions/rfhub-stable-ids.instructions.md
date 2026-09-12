---
description: Stable Robot identity tags the hub uses for history, queue, and metrics
applyTo: "**/*.{robot,resource}"
---

- Give every product one `project_id:<uuid>` on the suite root (`Force Tags` in the top `__init__.robot`). One id per product/repo; the hub is single-tenant and uses it only to filter runs.
- Give every catalog leaf (and each `__init__.robot` that should be selectable) a `suite_id:<uuid>` via `Force Tags`. Nested dirs may add their own `suite_id`; do not reuse a sibling’s id.
- Give every test case a `[Tags]    test_id:<uuid>`. Keywords never get identity tags.
- Keep those UUIDs **stable** when you rename files or titles. Names are labels; ids are identity.
- Generate new UUIDs with `uuidgen | tr '[:upper:]' '[:lower:]'`. Do not invent look-alike strings.
- Do not put `project_id` / `suite_id` / `test_id` / `exec_host_id` prefixes on ephemeral labels (`wip`). Hub Redis marks exist for WIP without committing file tags.
- `exec_host_id:<uuid>` is a runner/orchestrator concern (`EXEC_HOST_ID`), not something to stamp on every test.
