---
name: rfhub-write-suite
description: >-
  Use when creating or restructuring a Robot Framework leaf suite or
  __init__.robot for Robot Framework Hub: Test Tags project_id/suite_id,
  promoting shared tags up the tree, Documentation, Resource imports, catalog
  dry-run layout. Apply when the user says "new suite", "add a leaf under
  smoke", "write __init__.robot", or "move this tag to the parent". Does not
  activate for a single test case or keyword (rfhub-write-testcase /
  rfhub-write-*-keyword) or for queueing the suite.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-write-suite

Hub catalog dry-runs the tree; the orchestrator runs **leaf** suites. This skill owns the folder / `__init__.robot` / leaf `.robot` **Settings** — not individual test cases.

## When to use

- New directory under the suite root
- New or edited `__init__.robot`
- Splitting a huge file into schedulable leaves
- Promoting or demoting shared tags in the suite tree

## Instructions

1. One product `project_id:<uuid>` on the suite-root `__init__.robot` (`Test Tags`). Reuse the repo’s existing id; do not mint a second product id.
2. Each selectable folder/leaf gets its own `suite_id:<uuid>` on `Test Tags`. Generate with `uuidgen | tr '[:upper:]' '[:lower:]'`. Never change it on rename.
3. Pattern:

```robot
*** Settings ***
Documentation    Short purpose. Catalog and humans read this.
Resource         ../keywords.resource
Test Tags        suite_id:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

4. Tests inherit parent `Test Tags`. Put a product tag (`smoke`, `checkout`) on this suite when **every** descendant shares it. Promote common tags up the tree; demote when a sibling no longer matches — do not leave a uniform tag copied onto every child. Use `Test Tags`, never `Default Tags` (hub tests have `[Tags]    test_id:…`, which disables Default Tags).
5. Tests go in sibling `*.robot` files; `__init__.robot` is Settings/tags/resources, not a dump of all cases. Adding a case → **rfhub-write-testcase**.
6. Keep suite setup `--dryrun`-safe (catalog). No real browser/network in suite-level setup.
7. Import shared keywords from `*.resource` (**rfhub-write-resourcekeyword**), not copy-paste.
8. After the leaf exists, queue with **rfhub-queue** (`suiteIds` = this `suite_id` or parent). Do not encode order in the folder name. Ephemeral `wip` is a Redis suite mark, not `Test Tags    wip` on every test.

Follow always-on instructions for ids, tag placement, leaves, Gherkin, and FAIL attachments.

## Gotchas

- Two leaves must not share `suite_id`. History and queue keys would collide.
- `SUITE_NAME` / longnames (`Synthetic.Smoke.Health`) are labels; UUIDs are identity.
- Repeating the same extra tag on every test in a leaf means it belongs on the suite.
- Do not add a custom `--listener` in Settings.
