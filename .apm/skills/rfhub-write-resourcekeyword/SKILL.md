---
name: rfhub-write-resourcekeyword
description: >-
  Use when adding or changing Robot keywords in a *.resource file for hub leaf
  suites (catalog dry-run, Resource imports): shared across leaves, or
  leaf/wave-private when the Keywords section would grow. Apply when the user
  says "resource keyword", "keywords.resource", "smoke-checks.resource", or
  "shared helper for several suites". Does not activate for tiny suite-private
  Keywords in a .robot file (rfhub-write-suitekeyword), Python libraries, or
  test cases.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.1"
---
# rfhub-write-resourcekeyword

Robot keywords in `*.resource`. Leaves `Resource` them; catalog `--dryrun` must still succeed.

## When to use

- Helper used by more than one leaf
- Leaf- or wave-private helpers next to the consumer when `*** Keywords ***` in the `.robot` would grow (e.g. `suites/wave1/wave1-smoke-checks.resource` beside `smoke.robot`)
- Editing something like hub synthetic `keywords.resource`

## Instructions

1. Create/edit `*.resource` near its consumers (suite root, or beside the leaf/wave). Import path relative to the leaf. Do not put wave-only helpers in a tree-wide `resources/` folder other waves will see.
2. `*** Settings ***` must document **purpose and scope** (what checks, which leaves/waves). Name the file for the domain (`wave1-smoke-checks.resource`), not jargon (`gates.resource`). `*** Keywords ***` only after Settings/Variables — no `*** Test Cases ***`.
3. Keep import and suite-level use dry-run safe: no browser launch, sleeps, or network as a side effect of importing the resource.
4. Leaves add `Resource    path.resource`. Do not `Force Tags` identity ids on the resource file unless every importer should inherit them (usually **do not** — `suite_id` belongs on the leaf). Shared product tags belong on suite `Force Tags` (**rfhub-write-suite**), not on the resource.
5. Keywords tell **how**. Simple `IF` / `FOR` may live here. Prefer stock Robot libraries: **Process** for commands, **OperatingSystem** for files, **Collections** / **String** for data. Higher-level wrappers may hide `Run Process` — do not reimplement process forking in Python. Complex decisioning, API clients, structured file parse, math, complex CSS, DOM churn, and JavaScript snippets → **rfhub-write-pythonkeyword**, logging what happened. `person turns to home from crossroads` is first-level; left vs right is deeper in the spine. Do not hide the actor’s **goal** behind one keyword the case calls as the whole story. The Gherkin case (**rfhub-write-testcase**) is the actor story.
6. Keywords called from a test case take **one** inlined `'${arg}'` (single quotes) with a meaningful word after the variable. Several values: each Gherkin-facing keyword `VAR    ${name}    ${value}    scope=TEST` (same case) or `scope=SUITE` (next test case in this leaf — `customer memorizes the order number` / `customer uses the memorized order number`). First-level names stay human; deeper keywords get technical and eventually Python. Do not put two embedded args on one Gherkin-facing name. Deeper keywords may take arguments any way.
7. FAIL messages that include screenshots must still use `OUT_DIR`-relative paths (hub attachment matching).
8. Need native code, sockets, or Browser/Playwright internals → **rfhub-write-pythonkeyword** (and likely a runner overlay image).
9. A few suite-private helpers used only in one file → **rfhub-write-suitekeyword**. Growing Keywords section → this skill (leaf-local `.resource` is fine).

## Gotchas

- Catalog mounts the suite and runs `robot --dryrun`. A resource that opens Chrome at import time breaks inventory and Play-from-hub.
- `PYTHONPATH` does not replace `Resource` for `.resource` files.
- A shared `Complete Checkout` that performs the whole actor path is a Gherkin smell — flatten it into the case.
- Complex CSS, DOM churn, and `Execute Javascript` in a `.resource` belong in Python (**rfhub-write-pythonkeyword**).
- Gherkin-facing names: `My nice keyword takes '${businessArguments}' inlined`. Never end on the variable (`My nasty keyword takes inlined ${businessArguments}`). Unquoted `${var}` plus a formatter’s double space cuts the keyword into a different call.
- `VAR` without `scope=TEST`/`SUITE` is keyword-local; later steps will not see the context. `scope=SUITE` does not cross hub leaves.
