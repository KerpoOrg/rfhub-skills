---
name: rfhub-write-testcase
description: >-
  Use when adding or changing a Robot Framework test case for Robot Framework
  Hub: Gherkin Given/When/Then, [Tags] test_id UUID, FAIL messages with
  OUT_DIR-relative attachments, keeping the case in a schedulable leaf. Apply
  when the user says "add a test", "write this test case", "Gherkin", or
  "give it a test_id". Does not activate for suite Settings/__init__.robot,
  shared keywords, or queueing.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.1"
---
# rfhub-write-testcase

One `*** Test Cases ***` row that the hub can history, flake-chart, and attach screenshots to. Prefer Gherkin: readable like a book, one path, actor story on the case.

## When to use

- New test in an existing leaf `.robot`
- Adding `test_id:` to a case that only has a human name
- Rewriting a case into Gherkin / flattening hidden user steps
- Changing FAIL/screenshot behavior so hub digests link attachments

## Instructions

1. Confirm the file is a **leaf** the catalog can run. If you need a new folder, **rfhub-write-suite** first.
2. Every case has a stable `test_id` and a Gherkin body:

```robot
Customer completes checkout
    [Tags]    test_id:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Given the cart contains a shippable item
    When the customer opens checkout
    And they enter '${address}' as shipping address
    And they pay with '${card}' as payment
    Then the order is confirmed
```

3. Mint `test_id` with `uuidgen | tr '[:upper:]' '[:lower:]'`. **Never change it** if you rename the title.
4. Gherkin:

   - Robot strips `Given` / `When` / `Then` / `And` / `But` when matching keywords.
   - One execution path. People think straight, not in loops or `IF` / `ELSE`. No branching in the case. Another actor **goal** = another case. Decision logic is hidden deeper in the keyword spine. Top-level: `person turns to home from crossroads` — they do not think left or right. Simple `IF` / `FOR` in Robot keywords; complex decisioning, CSS/DOM/JavaScript, and seams (command, API, math) in Python (**rfhub-write-pythonkeyword**), logging what it did.
   - Top-level steps must be enough to perform the test **manually** — a reader could follow them with a different how (CLI, UI, checklist). Do not collapse the story into one keyword.
   - The case states **what** is checked and **what must hold** (business artifacts and outcomes: `hub web production image`, `order is confirmed`). Tool names (`pnpm`, `hadolint`, script paths) belong in keywords / deeper HOW, not in Gherkin steps. Optional `[Documentation]` can spell What / Expected in business terms.
   - Keywords tell **how**. Deeper in the hierarchy the steps get technical; prefer Robot `Process` / `OperatingSystem` before Python (**rfhub-write-pythonkeyword**). User interactions stay in the case unless the step is totally technical.
   - Keywords on the Gherkin line take **one** inlined `'${name}'` (single quotes) and must not end on the variable. Right: `My nice keyword takes '${businessArguments}' inlined`. Wrong: `My nasty keyword takes inlined ${businessArguments}`. After indent, only single spaces — two or more spaces is a new Robot cell.
   - Several values for a later step **in the same case**: one Gherkin line per value, `Set Suite Variable    ${name}    ${value}`. Carry a value **to the next test case** in this leaf with `Set Suite Variable` too (`customer memorizes the order number` → `customer uses the memorized order number`). Both cases must stay in the same `.robot` leaf — hub runs one Robot process per leaf. Do not cram `'${email}'` and `'${name}'` into one first-level keyword. Deeper keywords may take arguments any way. Do not hand off with `VAR … scope=TEST` / `scope=SUITE` — Robocop (`VAR06` `no-test-variable`, `MISC04`) flags it; `Set Suite Variable` is Robocop-clean.

```robot
Customer registers
    [Tags]    test_id:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    When customer decides to register
    And chooses '${email}' as username
    And chooses '${name}' as name
    Then customer fills the form
    And clicks submit

Customer creates an order
    [Tags]    test_id:yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
    When customer places an order
    Then customer memorizes the order number

Customer sees the order on the dashboard
    [Tags]    test_id:zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz
    When customer opens the dashboard
    Then customer uses the memorized order number
```

5. On failure with a sidecar, include an `OUT_DIR`-relative path in the message (`attachment #1: test-results/…/test-failed-1.png`). Hub matches message text to uploads.
6. Set a per-case `[Timeout]` from expected runtime / execution history (observed max × ~3, with a small floor for fast checks). Prefer case-level timeouts over one large suite `Test Timeout` when cases have very different costs.
7. Keep the case in one leaf; do not rely on `--test` in a consumer args file for orch batches.
8. `[Tags]` holds `test_id` and tags **unique to this case**. Do not repeat parent `Test Tags`. If every case in the leaf would get the same extra tag, put it on the suite (**rfhub-write-suite**). Do not stamp `wip` on each test — mark the suite via **rfhub-queue** Redis (`kind: suite`) unless the leaf is only partially WIP. Never use identity prefixes (`project_id`, `suite_id`, `test_id`, `exec_host_id`) as ephemeral labels.

## Gotchas

- Missing `test_id` means hub history keys off names — renames split the series.
- `Default Tags` do not apply once a case has `[Tags]` (every hub case does). Shared tags must be `Test Tags` on the suite.
- `Set Suite Variable` values live for the leaf process; suite variables do not cross hub leaves. A plain `VAR` (without `scope=`) stays keyword-local.
- Unquoted `${var}` in a Gherkin-facing name is formatter bait: `takes ${businessArguments}` becomes `takes    ${businessArguments}` (two spaces = new cell) and it is a different keyword. Keep `'${businessArguments}'` and a word after it so the step stays one cell.
- `And they pay with    ${card}` (separate argument cell) is wrong at case level. Inline it, quoted, and do not end on the variable: `And they pay with '${card}' as payment`. Never `And they pay with '${card}'` or `And they pay with ${card}`.
- Do not `Fail` with only an absolute host path the hub cannot open.
- Listener is already on the runner; tests must not register another.
- Hub synthetic/demo suites (Burn Time / Maybe Fail) are not product Gherkin — do not rewrite them.
