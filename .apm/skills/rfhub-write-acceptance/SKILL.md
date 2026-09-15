---
name: rfhub-write-acceptance
description: >-
  Use ONLY when the user is editing the acceptance criteria themselves —
  which waves form them and in which order (Settings → Acceptance). Apply
  when the user says "acceptance definition", "add a wave to acceptance",
  "update the acceptance criteria", "order the acceptance waves", or "which
  waves gate this release". Covers wave ids vs slugs (slugs accepted for
  convenience, stable ids stored server-side), order = queue order,
  per-wave parallelism is kept, waves must exist for the project. Not for
  running or queueing anything on the hub (even a "run acceptance" ask), reading report verdicts or investigating failures,
  queueing one wave ad-hoc, fixing failures until green, or
  creating/editing leaf suites, test cases, or keywords in
  .robot/.resource files.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-write-acceptance

A project **acceptance definition** is the ordered list of **waves** that form the project's acceptance criteria (hub UI: project → Settings → Acceptance). Order is queue order. There are no file edits — the definition lives on the hub.

> **Access requirement:** needs hub access like **rfhub-queue** (MCP OAuth or API key), on a hub that ships the acceptance API. Non-functional without it.

## When to use

- "Add the new security wave to the acceptance definition"
- "Update the acceptance criteria / order the acceptance waves"
- "Which waves gate this release?"
- Setting up acceptance for a project for the first time

Not for running acceptance (that is **rfhub-queue**), reading a report verdict (that is **rfhub-investigate**), queueing one wave ad-hoc, or editing `.robot` sources.

## Instructions

1. Resolve `project` (`project_id` UUID or configured name). Read the current definition first: `GET /api/agent/acceptances?project=…` (waves with their stable ids, in order).
2. Pick waves that already exist for the project (`GET /api/agent/waves?project=…`). Every entry must reference an existing wave — the save does not create waves.
3. Write the order deliberately: position N queues before position N+1 at run time. Put fast, high-signal waves first so a cheap failure stops the story early; keep the full criteria complete, not just the fast subset.
4. Save with `PUT /api/agent/acceptances` (`project` + ordered wave entries). **Slugs are accepted for convenience but stable wave ids are stored server-side** — prefer ids when you have them (they survive renames), slugs when the human speaks in slugs. Confirm the stored order in the response.
5. Per-wave `parallelism` is kept: each wave runs with its own scheduling granularity (`serial` / `suite` / `testcase`). The definition does not impose one parallelism for all waves — tune it on the wave (`PUT /api/agent/waves`), not in the acceptance definition. When confirming the save, state the order and that each wave keeps its own parallelism.
6. Remove with `DELETE /api/agent/acceptances?project=…&slug=…` (or the definition-level delete) only when the criterion itself is retired — removing a wave from acceptance does not delete the wave.
7. After changing the definition, the next **rfhub-queue** acceptance run uses it. Do not re-queue past runs to "apply" the edit — reports already created keep the definition they ran with.

## Gotchas

- Slugs are labels, ids are identity — same rule as `suite_id` / `test_id`. A renamed wave keeps its id; a definition saved with slugs resolves them once, at save time.
- Referencing a wave that does not exist for the project fails the save. Create the wave first (hub Settings → Waves or `PUT /api/agent/waves`).
- Order is the only sequencing control. There is no per-entry condition or branch — one execution path, waves in definition order, one environment.
- Do not confuse the acceptance definition with an acceptance **report**: the definition is the criteria (waves in order), the report is the evidence for one commit (verdict `passed` / `failed`).
