---
name: rfhub-write-suitekeyword
description: >-
  Use when adding or changing a Robot keyword in the same .robot file as the
  tests (suite-local Keywords section) for a hub-managed suite. Apply when
  reuse is only that file. Does not activate for *.resource keywords
  (rfhub-write-resourcekeyword), Python libraries (rfhub-write-pythonkeyword),
  or test cases / suite Settings.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.1"
---
# rfhub-write-suitekeyword

Suite-private keywords in the same `.robot` as the cases. Identity tags stay on the **suite and test**, never on the keyword.

## When to use

- Helper used only by tests in this file
- User says “keyword in this suite file”

## Instructions

1. If a second leaf will need it, or this file’s `*** Keywords ***` is growing, **rfhub-write-resourcekeyword** instead (leaf-local `.resource` beside the suite is fine). Do not duplicate across leaves.
2. Add under `*** Keywords ***` in that `.robot`. No `project_id` / `suite_id` / `test_id` tags on the keyword.
3. If this keyword is called from a test case, name it with **one** inlined `'${arg}'` (single quotes) and a meaningful word **after** the variable: `My nice keyword takes '${businessArguments}' inlined`. Never end on the variable (`My nasty keyword takes inlined ${businessArguments}`). Do not use a separate `[Arguments]` list for those values on the Gherkin line.
4. Several business values: each Gherkin-facing keyword stores one value into test (or suite) context. Later first-level keywords read the variables — they do not take a list of embedded args. Hub runner is Robot 7.3 — use `VAR`, not `Set Test Variable`:

```robot
chooses '${email}' as username
    VAR    ${username}    ${email}    scope=TEST

chooses '${name}' as name
    VAR    ${name}    ${name}    scope=TEST

customer fills the form
    Fill Email Field    ${username}
    Fill Name Field     ${name}

customer memorizes the order number
    ${order}=    Read Order Number From Confirmation
    VAR    ${order_number}    ${order}    scope=SUITE

customer uses the memorized order number
    Page Should Contain    ${order_number}
```

   `scope=TEST` for later steps in this case. `scope=SUITE` when the actor memorizes a value for a later test case in the **same leaf**. First-level names stay human; `Read Order Number From Confirmation` / `Page Should Contain` / Python are deeper HOW. Suite variables do not cross hub leaves. `VAR` without `scope=` is keyword-local. Keywords only called from other keywords may take arguments any way (`[Arguments]`, positional, named).
5. Keywords tell **how**. Simple `IF` / `FOR` may live here. Prefer `Process` / `OperatingSystem` / `Collections` for commands and files. Complex decisioning, API clients, structured parse, math, complex CSS, DOM churn, and JavaScript snippets → **rfhub-write-pythonkeyword** (log the outcome; keep the Robot log tidy). Top-level: `person turns to home from crossroads`. Left vs right lives deeper in the spine, not as Gherkin steps. Do not hide the actor’s **goal** behind a keyword the case calls as the whole story (`Complete Checkout`). User interactions that are the story stay in the case unless the step is totally technical (selectors, waits, encoding).
6. Suite setup/teardown keywords must stay catalog `--dryrun`-safe (no real I/O at import/suite setup).
7. On FAIL inside the keyword, still put `OUT_DIR`-relative attachment paths in the message so hub digests match uploads — the test case owns `test_id`.
8. Do not register a Robot listener from a keyword.

## Gotchas

- Keywords are not catalog queue units. Queue **leaf suites**, not keyword names.
- A growing `*** Keywords ***` in one file is a signal to move to a leaf-local `.resource` (**rfhub-write-resourcekeyword**), even if only this leaf imports it.
- A keyword named like `Complete Checkout` that performs the whole actor path is a Gherkin smell — flatten it into the case.
- Complex CSS, DOM churn, and `Execute Javascript` in this `.robot` file belong in Python (**rfhub-write-pythonkeyword**).
- `VAR` without `scope=` is keyword-local; later Gherkin steps will not see the value. Use `scope=TEST` in this case, `scope=SUITE` for the next test case in this leaf (not another hub leaf).
- Unquoted `${var}` at the end of a Gherkin-facing name is formatter bait: `My nice keyword takes ${businessArguments}` becomes `My nice keyword takes    ${businessArguments}` and Robot sees a different keyword. Always `'${arg}'` plus a trailing word; only single spaces after indent.
- `Pay With    ${card}` as a Gherkin-facing keyword is wrong. Embed the value in single quotes and do not end on it: `they pay with '${card}' as payment`. Never `they pay with '${card}'` or unquoted `${card}` at the end.
