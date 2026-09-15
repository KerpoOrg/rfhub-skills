---
name: rfhub-atdd
description: >-
  Use for acceptance-test-first (ATDD) feature or bugfix work on Robot
  Framework Hub — prefer this over the generic rfhub map and rfhub-queue when
  the acceptance suite does not exist yet: the suite is written first so it
  runs RED on the hub, the SUT is implemented test-first with TDD (kerpo-tdd
  inner loop), the same handle is rerun until GREEN, and evidence is
  commit-bound. Triggers: "atdd", "acceptance test first", "write the failing
  acceptance test first", "red then implement", "acceptance test driven
  development", "implement issue N test first", "implement issue N, and
  deliver pr", "roll it out to acceptance environment", "roll it out to
  production". The delivery wording sets how far to go — never past it. Does
  not activate for plain unit TDD (kerpo-tdd), fixing existing failures with
  no spec-first gate (rfhub-fixloop), queue-only asks (rfhub-queue), or
  failure investigation (rfhub-investigate).
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-atdd

Double-loop, test-first development where the **outer loop is a hub acceptance suite** and the **inner loop is TDD** (compose **kerpo-tdd** for it): write the acceptance cases first, confirm they run **red for the right reason**, only then implement, iterating the same hub handle until green, and confirm with acceptance evidence. Like rfhub-fixloop this skill owns **loop control**; it composes rfhub-write-*, rfhub-queue, rfhub-investigate and kerpo-tdd for the steps.

> **Access requirement:** hub access like **rfhub-queue** (MCP OAuth), a suite worktree you may change, and the SUT repo writable. Non-functional without all three.

## Vocabulary

- **Outer loop** — acceptance tests, business view, red→green over hours; each case is an executable specification of one business outcome.
- **Inner loop** — unit TDD (red→green→refactor, minutes); happens under a confirmed-red acceptance case.
- **Wishful thinking** — the case is written as if the feature already existed. Red must be *missing feature*, never broken harness.
- **Process gate** — one failing acceptance case at a time; the next case is formulated only after the current one is green or explicitly parked.
- **Delivery horizon** — how far the user's wording takes the loop (below).

## Delivery horizon — the wording decides

Read the **delivery wording** in the user's ask; it defines where the loop stops. Never go past it.

| User wording | Horizon |
|---|---|
| "implement issue #N" / "make the acceptance test pass" | Formulate → RED → inner TDD → handle green. Report and stop. |
| "…and deliver pr" | Above, then: commit(s) referencing the issue, push, open PR. Do not merge unless told. |
| "…and roll it out to acceptance environment" | Above, then: queue the project **wave/environment for accpt** with the final `gitSha` and show acceptance evidence (gate green). |
| "…roll it out to production" | Above tiers, then: prod environment with its own gates. Explicit "production" wording only — "acceptance" is never prod. |

If the wording is ambiguous ("ship it"), stop at the last completed tier and ask. Each tier boundary is a natural checkpoint for the user to say "go on".

## The loop

### Phase 1 — Distill (three amigos)

1. With the user, capture acceptance criteria as **concrete examples**, one business outcome per case. Follow repo AGENTS.md Gherkin rules (human-readable, no branching in the case body).
2. Decide the **leaf layout** up front: leaves must be independent (suite variables do not cross leaves), dry-run safe, with stable `project_id` / `suite_id` / `test_id`.

### Phase 2 — Formulate (write the spec, expect red)

1. Write the leaf with **rfhub-write-suite** + **rfhub-write-testcase** (wishful thinking). FAIL messages carry OUT_DIR-relative attachment paths from the start.
2. Do **not** implement any SUT code yet.

### Phase 3 — RED on the hub

1. Queue **only what you formulated** on the hub with `gitSha` (see "Running fast" below). Use `rfhub_tag_set` (`kind: suite`, `wip`) — the honest "spec written, feature not implemented yet" mark.
2. Verify red **for the right reason** with **rfhub-investigate** (`rfhub_run_log`, excerpts first). Catalog/harness errors are not red — fix the harness first; still no SUT code.
3. This gate is mandatory: **no implementation before red is confirmed.** An implementation before a failing acceptance test is not ATDD.

### Phase 4 — Inner loop to green

1. Pick the first red acceptance case. Implement test-first with **kerpo-tdd**: unit red→green→refactor inside the SUT, minutes-level cadence.
2. After each inner-loop increment, **rerun into the same handle** (`rfhub_rerun({ runId })` with the touched `suiteIds`/`testIds`) — never a new `rfhub_queue` per iteration. Watch the case approach green.
3. If red persists, use the **rfhub-fixloop** discipline: one fix class per iteration, budget per `test_id`, `wip` as honest exit, never rerun-to-see-if-it-goes-away.
4. Green case → next red case (process gate). Park a case with `wip` + a one-line report rather than drifting the spec.

### Phase 5 — Confirm (Demo / Done)

1. All formulated cases green on the same `gitSha`; `rfhub_batch` `pending` empty.
2. Remove the `wip` mark. Pass `gitSha` on everything — evidence is commit-bound.
3. **If the horizon is acceptance/production**: queue the project wave/environment with the final `gitSha`, then require acceptance-gate green (or an acceptance report from ≥2 passed runs sharing projectId+gitSha). Do not build a report until runs actually passed.
4. **If the horizon is PR**: after green confirmation, deliver the PR (issue-linked, checklist/implementation-notes conventions apply).
5. End in an explicit state: green (evidence), PR opened, environment rolled out, `wip`-marked, or escalated. Never silent.

## Running fast — only the code path

The hub makes a slow ATDD loop fast; keep the executed set minimal:

- **Iteration reruns** — `rfhub_rerun` with just the touched leaves' `suiteIds`, or `testIds` for a single case. Do not rerun the whole wave while developing.
- **Single case** — `testIds` include of only the case in the code path; this is exactly what `parallelism: testcase` is for.
- **Parallel suites** — independent leaves can run as `parallelism: suite`; concurrent cases inside one leaf share the executor, so keep leaves small.
- **Full catalog only at tier boundaries** — the acceptance/production confirmation (or an `all: true` / wave queue for the gate) runs the wide selection once, at the final `gitSha`, not per iteration.
- Fast inner loop first: cheap unit TDD locally, then a hub rerun only when an increment could change acceptance behavior.

## Invariants

- **One handle per acceptance case.** Reruns overlay; new queues are new evidence. Pass `gitSha` on any new queue.
- **Spec before code.** Red confirmation gates all implementation.
- **One failing acceptance case at a time** — formulate the next only after green or an explicit park.
- **Spec changes are decisions, not drift absorption.** Green must come from implementation. If reality contradicts the case, flag the drift to the user and update the case as an explicit step (keep `test_id` stable).
- Every iteration gets a one-line report: case → what changed (file + why) → rerun outcome.

## Gotchas

- "Rollout" tiers depend on project environments (`dev` / `accpt` / `prod` slugs differ); confirm the environment slug before queueing, and confirm the *acceptance* wave is what accpt actually runs.
- A green on rerun can be a flake, not a fix — check `rfhub_metrics_test` before celebrating.
- Suite variables do not cross hub leaves (separate Robot processes). Value hand-off steps must live in the same leaf as their readers.
- Never edit `OUT_DIR/rfhub.args` (runner-generated) to make red go away.
- Do not `rfhub_rerun` while that part is still executing; mid-run edits never reach running executors.
- WIP marks live in hub Redis (TTL, per branch) — set via `rfhub_tag_set`, clear via `rfhub_tag_clear`; do not commit `wip` tags to files.
- The acceptance suite is also the deliverable: keep Gherkin case steps performable manually, keywords technical.
