---
name: rfhub-atdd
description: >-
  Use ONLY for acceptance-test-first (ATDD) development on Robot Framework Hub,
  when the acceptance suite is NOT written yet and must be formulated first to
  run RED on the hub before any implementation — "atdd", "acceptance test
  first", "write the failing acceptance test first", "red then implement",
  "acceptance test driven development", "implement issue N test first",
  "implement issue N, and deliver pr", "roll it out to acceptance
  environment", "roll it out to production". Composes the outer double loop
  around TDD: acceptance cases RED first, SUT implemented with TDD as the
  inner loop, the same hub handle rerun until the acceptance cases pass with
  commit-bound evidence; the delivery wording sets the horizon and is never
  exceeded. Not for work on suites whose cases already exist and fail,
  queueing or investigation-only asks, shared-fixture lock domains, or TDD
  without an acceptance-first gate.
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
- **Acceptance test vs unit test** — an acceptance case is an executable business outcome on the hub; a unit test is an inner-loop seam test. They are different layers and one never stands in for the other.

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

### Phase 0 — Preflight (environment must be runnable before any edit)

1. Confirm hub access (**rfhub-connect** first if MCP is down).
2. Confirm `project` + `branch` resolve and an **online orchestrator** is registered for that pair (`rfhub_projects` / orch UI) — Phase 3's RED confirmation and every Phase 4 rerun depend on it.
3. If the SUT needs a local stack or other dev services to execute, start and verify them now.
4. If any of the above cannot be satisfied, **stop before touching repository files**: report what's missing (no orchestrator registered, hub unreachable, stack down) and ask the user, or fix the environment first. Formulating specs or editing sources against an environment that cannot run them only defers the failure to Phase 3.

### Phase 1 — Distill (three amigos)

1. With the user, capture acceptance criteria as **concrete examples**, one business outcome per case. Follow repo AGENTS.md Gherkin rules (human-readable, no branching in the case body).
2. Decide the **leaf layout** up front: leaves must be independent (suite variables do not cross leaves), dry-run safe, with stable `project_id` / `suite_id` / `test_id`.
3. **The issue's test strategy does not override the outer loop.** If the issue (or a linked plan) defers hub coverage to a child issue, or prescribes unit tests as "the test strategy" for this work, that is a scoping decision only the user can make. Formulate the hub acceptance cases anyway and confirm red first; if hub coverage is genuinely impossible for this work (no hub access, feature not exercisable on the hub), stop and ask the user or park explicitly with a one-line report before any SUT code. Never substitute unit tests for the outer loop.

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
3. **If the horizon is acceptance/production**: queue the project wave/environment with the final `gitSha` via **rfhub-queue**'s "Running acceptance" flow — discover the correct acceptance definition slug first (do not assume the default `acceptance`; a PR-triggered gate is often a differently-named, WIP-scoped definition), then require acceptance-gate green (or an acceptance report from ≥2 passed runs sharing projectId+gitSha). Do not build a report until runs actually passed.
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
- **Unit tests are never the outer loop.** An issue's test strategy that defers or prescribes a different test layer does not change the gate: acceptance cases are always formulated and confirmed red on the hub first. If hub coverage is deferred or impossible, ask the user or park explicitly — never swap unit TDD in as the outer loop.
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
- A deferral note in the issue body ("hub TXN coverage added to suite X in child issue") is not permission to skip the hub — follow the Phase 1 rule and surface the conflict to the user instead of silently swapping the test layer.
- Confirming the hub/orchestrator before Phase 2 is not optional — a "red" confirmed against a missing orchestrator is a broken harness, not RED (Phase 0).
- When rolling out to acceptance, do not assume the `acceptance` slug or fall back to hand-picked waves if the run reports no criteria or an empty WIP scope — discover the right definition and WIP marks per **rfhub-queue** instead.
