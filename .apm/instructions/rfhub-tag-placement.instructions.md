---
description: Promote shared Robot tags up the suite tree; demote when children diverge; WIP is usually a suite mark
applyTo: "**/*.{robot,resource}"
---

- Tests inherit tags from parent suites (`Force Tags` on `__init__.robot` and the leaf). Do not repeat a tag on every child if a parent already applies it.
- If every test (or every child suite) shares a tag, set it on that parent. This applies to the entire hierarchy.
- Promote common shared tags upwards. Demote when uniformity is no longer true — a sibling does not share the tag, so move it down onto the children that still do.
- Use `Force Tags` for shared tags, never `Default Tags`. Hub cases always have `[Tags]    test_id:…`, and Default Tags are skipped once a case has any tags of its own.
- Identity tags stay as today: one `project_id` on the product root, a `suite_id` on each selectable suite, a `test_id` only on the case. Do not promote `test_id`. Do not put identity prefixes on ephemeral labels (`wip`).
- When marking WIP, mark the **entire suite**, not each test. Cases in a suite are usually interdependent. Mark individual tests only when the suite is partially WIP.
- Ephemeral WIP still prefers hub Redis (`rfhub_tag_set` with `kind: suite`) over committing `Force Tags    wip`. The same suite-vs-test rule applies to Redis marks.
