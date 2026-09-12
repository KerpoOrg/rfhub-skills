---
name: rfhub-write-pythonkeyword
description: >-
  Use when writing a Robot Framework Python library keyword for suites that
  run on Robot Framework Hub (PYTHONPATH, suite mount, overlay image): seams
  that Process/OperatingSystem cannot cover (HTTP/API clients, file parsing,
  math), complex CSS/DOM/JavaScript, or complex branching with logger.info.
  Apply when the user says "Python keyword", "library.py", "CSS selector",
  "Execute Javascript", "call an API from Robot", or "complex IF in Python".
  Does not activate for simple Robot IF/FOR, Process/OperatingSystem wrappers,
  editing hub TypeScript, rfhub_listener.py, or Robot .resource/.robot keywords.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.2"
---
# rfhub-write-pythonkeyword

> **Runner image access:** the overlay base image is served from a private
> registry today (`harbor.kerpo.org/library-private/...`). Use the image your hub
> operator provides; a public runner image is planned. See the package README,
> "Access requirements".

Python libraries ship **in the suite** (or overlay image). Robot still runs in the runner container, never in the Next.js hub.

## When to use

- Custom library under e.g. `libs/` imported with `Library    MyLib`
- A **seam Process cannot cover**: HTTP/API client, structured file parse, math, native code
- Complex CSS selectors, DOM manipulation/churn, JavaScript snippets
- Complex decisioning / branching (log what it did). Simple `IF` / `FOR` stays in Robot.

## Instructions

1. Put modules on the path the container sees: suite mount (`/suite/libs`) plus `PYTHONPATH=/suite/libs`, or bake into a **runner overlay** (`FROM harbor.kerpo.org/library-private/rf-hub-runner:pabot`). Do not fork `entrypoint.sh` or vendor `rfhub_listener.py`.
2. Robot import: `Library    MyLib` (module on `PYTHONPATH`) or `Library    /suite/libs/MyLib.py`.
3. Keywords should not start a second listener. Live events come from the image’s `rfhub_listener.py`.
4. Catalog `--dryrun` imports libraries. Import-time side effects (opening browsers, connecting to prod) break inventory. Defer I/O to keyword calls; dry-run should no-op.
5. Screenshots/files the hub should show: write under `OUT_DIR` and put the **relative** path in `BuiltIn.fail` / assertion messages (same as Robot FAIL attachments).
6. Prefer stock Robot libraries before Python. **Shell / subprocess** → `Process` (`Run Process`) in a `.resource` or suite keyword — do **not** reimplement forking, stdout/stderr capture, or env wiring in Python. **Files / dirs** → `OperatingSystem`. **Dicts / lists** → `Collections`. Python is for seams those libraries do not cover (API clients, structured parse, math, browser guts, **complex** decisioning). In Python, `from robot.api import logger` and `logger.info(...)` what the keyword decided or did so the Robot log stays tidy.
7. Keep Gherkin-facing names in Robot (`.robot` / `.resource`). Python keywords are **technical HOW** called from those layers (`Run Skills Audit For Package`, `Parse Frontmatter`). Do **not** implement the actor story as `@keyword("'${x}' is checked…")` in Python. If a rare Python keyword must be called directly from a test case, use an embedded-argument name with single quotes that does not end on the variable (`@keyword("they pay with '${card}' as payment")`). Context-setters belong in Robot (`Set Suite Variable    ${name}    ${value}`; not `VAR … scope=TEST` — Robocop `VAR06` / `MISC04`). Helpers only called from other keywords may take arguments any way.
8. `:latest` / `:pabot` do **not** include `robotframework-browser` / Chromium / Node. Overlay if you need them.
9. Pure Robot helpers → **rfhub-write-resourcekeyword**. Suite-private Keywords section → **rfhub-write-suitekeyword**.
10. **Unit-test every Python library** you add or change (`pytest` next to the library). In this hub repo, acceptance libraries under `acceptance/libraries/` must keep tests + a coverage baseline and stay green under Wave 1 (`scripts/test-coverage-scope.sh acceptance-libraries`). Do not ship a Robot Python seam without tests.

Overlay notes: [references/overlay.md](references/overlay.md).

## Gotchas

- Host `pip install` does not reach the executor. Dependencies belong in the overlay or a wheel mounted into `/suite`.
- `WORKDIR` default `/work` may be a shared bind; do not write `rfhub.args` yourself (runner owns `OUT_DIR/rfhub.args`).
- A nested Robot `IF`/`FOR` tree that buries the outcome in log.html belongs in Python with `logger.info`, not more Robot branches — but a plain `pnpm lint` / `bash scripts/foo.sh` belongs in `Process`, not a custom `subprocess` library.
- Complex CSS, DOM churn, and `Execute Javascript` in a `.robot` / `.resource` file belong in Python — they noise the log and leak implementation into the story.
- A Gherkin-facing `@keyword` (rare; prefer Robot) must use `'${arg}'` and must not end on the variable.
- Untested Python keywords regress silently in Hub executors — Wave 1 coverage gate fails closed.
