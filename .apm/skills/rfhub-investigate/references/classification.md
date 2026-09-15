# Fault classification — signal → verdict

Six fault classes and what usually proves each. Ladder rungs (cheap → expensive):
test history → suite diff vs main → git history on main → issues (current + past) → SUT state → hub/harness state. A verdict needs the strongest available signals, not all of them. Source: rfhub-investigate SKILL.md, "Classify the fault".

| Verdict | Discriminative signals |
|---|---|
| **Faulty test logic** | Never passed since creation, on any branch/environment; message stable across runs. Or: suite diff vs main shows the failing test (or a keyword/resource it imports) changed while the product did not. Or: rerun with no product change still fails identically while other tests in the leaf pass. |
| **Faulty implementation** | Test passed on an earlier `gitSha`; product commits since; suite sources unchanged vs `main`; same failure reproduces on rerun. `repeatingErrors` started right after a product change. |
| **Feature drift** | The test encodes behavior the product used to have; implementation matches the *current* plan/issue/AC, the test does not. Issue history shows the feature was deliberately changed (changelog, closed issue, design doc) after the test was written. |
| **Unclear plan** | Test, implementation, and issue all look internally correct but contradict each other; or acceptance criteria are missing, vague, or self-contradictory. Verdict = the plan is the fault — hand to the human, do not pick test-vs-code. |
| **Faulty test environment** | Pass/fail flips with no source change on either side. Passes in one `environment`, fails in another (read the run's `environment` + its `excludeTags` — selection changes can fake a regression). Fails only in batch parallelism or with shared fixtures. Timeouts near an observed max. Also: the feature flag gating the failing codepath is off (or default-off) on the SUT while the test assumes it on — flag state is configuration, and config mismatches live here. |
| **Faulty harness** | Process-shaped, not test-result-shaped: executor crash/timeout before test start, live "no-listener" hint, attachments never arrive, `source: "unavailable"` on metrics, same infra error across unrelated leaves/queues, parts never uploaded. Report via **rfhub-feedback**, not suite edits. |

## Flake vs the six classes

Repeated rerun-until-pass is a *symptom*, not a verdict. Map it:

- green on rerun with no change, flips recorded in `rfhub_metrics_test` → usually **faulty test environment** (timing/order/shared fixture) or weak **test logic** (selector race, sleep-based waiting). Fix the cause; do not loop reruns.
- passes only after sources were edited between runs → a real fix or a masked defect — diff what changed.

## Cross-checks that prevent wrong verdicts

- **Feature flags first.** If the SUT uses feature flags, check the state of every flag on the failing codepath before blaming implementation or test logic: a symptom identical to a product bug (endpoint 404s, UI element absent, empty data) often means the feature is simply toggled off in that environment. Flag off where the plan says it should be on → config/environment issue or drift between environments; flag state ambiguous across environments → check with the plan before choosing a fix.
- `rfhub_runs` carries `environment`: compare like with like; a pass-rate shift after an `excludeTags` change is selection, not regression.
- A test that never passed is a test-logic suspect *even if* the product is brand new — new feature + new test both failing is still a classification (usually implementation **or** test logic; the ladder decides).
- One failed leaf ≠ the product broke: check whether sibling leaves in the same batch passed, and whether the same `test_id` failed in older runs (`rfhub_test` history) before blaming the newest commit.
- Past issues with the same error fingerprint turn a "new bug" verdict into a known incident — search before declaring novelty.

## Handoff per verdict

| Verdict | Next move |
|---|---|
| Faulty test logic | Fix suite sources (**rfhub-write-***); keep `test_id` stable |
| Faulty implementation | Out of suite scope: hand to the user / product repo; suite-side only a cleaner FAIL message |
| Feature drift | Update the test to the current plan (with the issue as evidence), or flag the drift back if the plan is wrong |
| Unclear plan | Stop and ask the human; do not guess a side |
| Faulty test environment | Fix env/config/scheduling in suite or environment settings (`PUT /api/agent/environments`); otherwise report |
| Faulty harness | **rfhub-feedback**; do not edit suite sources |
