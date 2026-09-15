---
name: rfhub-fixloop
description: >-
  Use ONLY when the user asks to fix hub test failures across repeated
  fix-attempt-and-verify cycles until a batch is green: the agent loops
  diagnose → edit sources → rerun failed leaves into the same handle → verify,
  under a retry budget with stop conditions. Apply when the user says "fix the
  failures until green", "iteratively fix", "fix loop", "keep fixing and
  rerunning", "autonomous issue fixing", "make the batch pass", or "fix it
  and rerun" — more than one fix attempt is wanted. One-off run inspection,
  flake questions, and single-explanation answers belong to
  rfhub-investigate; authoring or editing a single test file belongs to
  rfhub-write-*; queueing or polling a run without fixing belongs to
  rfhub-queue. Activate only when fixing across attempts is the request
  itself.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-fixloop

Iterate **diagnose → fix sources → rerun into the same handle → re-check**, under a retry budget, until the batch is green or a stop condition fires. This skill composes existing skills; it owns **loop control**, not the individual steps.

> **Access requirement:** needs hub access like **rfhub-queue** / **rfhub-investigate**, plus a suite worktree you are allowed to change. Non-functional without both.

## When to use

- "Fix the failed suites until the run is green"
- "Iteratively fix / fix loop / keep fixing and rerunning"
- A batch finished with failures and the user wants them **fixed**, not just reported

Not for a single "why did this fail" — that is **rfhub-investigate** alone, no loop.

## One iteration (the loop body)

1. **Diagnose** with **rfhub-investigate** (`rfhub_failures` → `rfhub_run_log`, excerpts + `attachments[]` first) and run its **Classify the fault** ladder (test history → diff vs main → git history on main → issues → SUT state → hub state). Classification is the investigate skill's job — do not re-invent it here.
2. **Act on the verdict**:

   - **Faulty test logic** → fix the case/keywords with **rfhub-write-***, keep `test_id` stable.
   - **Faulty implementation / unclear plan / faulty harness** → not fixable in suite sources. Stop the loop for this test; report (harness suspicion → **rfhub-feedback**). Never keep rerunning to "see if it goes away".
   - **Feature drift** → update the test to the current plan (issue as evidence), or flag the drift back if the plan is wrong.
   - **Faulty test environment** (includes flake) → stabilize timing/order/fixture or fix environment settings. Do **not** treat rerun-until-pass as a fix.
   - Rewriting a flaky case into a deterministic one is a fix; deleting the test is not.

3. **Edit** only leaves inside this batch's scope. Minimal change, **one fix class per iteration** — so `progress.recovered` tells you which fix worked.
4. **Wait for idle**: do not `rfhub_rerun` while that part is still executing. Mid-run edits never reach running executors.
5. **Rerun into the same handle**: `rfhub_rerun({ runId: handle })`. Pass `suiteIds` for just the leaves you touched; default reruns failed leaves ∪ pending parts. **Never** open a second `rfhub_queue` to join results.
6. **Verify**: poll `rfhub_batch` with the same `handle` until `parts.pending` is empty. `progress.recovered` counts fail→pass on this join.
7. **Re-check** what is still red; loop back to 1.

## Budget and stop conditions

- Per `test_id`: at most **3** fix attempts. Third red result → stop for that test.
- Same `test_id`, **same error fingerprint** twice in a row (compare compact messages): rerunning again is not a fix — change something real, mark `wip`, or stop.
- Failure outside suite sources (product code, hub infra, environment) is **not fixable here**. Stop; never keep rerunning to "see if it goes away".
- **`wip` is an honest exit**: mark the suite via Redis (`rfhub_tag_set`, `kind: suite`) when the case is not ready, and say so.
- Global stop: budget exhausted, zero `recovered` across two consecutive joins, or the user set an iteration cap ("fix up to twice") — the user cap wins.

## Loop invariants

- **One handle for the whole loop** — reruns overlay the same run; new `rfhub_queue` calls are new batches.
- Keep the same `project` + `branch`; pass `gitSha` on any new queue call (fix commits should be commit-bound for acceptance evidence).
- One-line report after every iteration: what failed → what changed (file + why) → rerun outcome.
- The loop must end in an **explicit state**: green (offer an acceptance report if several runs share the `gitSha`), `wip`-marked, or escalated to the user. Never stop silently.

## Gotchas

- `progress.recovered` is per latest join — compare against the previous failure set, not the original batch.
- A pass on rerun can be a flake, not a fix; confirm with `rfhub_metrics_test` before declaring recovered.
- Never "fix" by deleting the test or editing `OUT_DIR/rfhub.args` (runner-generated).
- Do not rewrite mid-run fails that `rfhub_metrics_test` shows as long-term flaky — stabilize, don't churn.
