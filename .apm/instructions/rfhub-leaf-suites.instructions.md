---
description: Leaf-suite layout so hub catalog and orchestrator can schedule the suite
applyTo: "**/*.{robot,resource}"
---

- The catalog dry-runs the suite tree and posts inventory. The orchestrator executes **leaf** suites (one Docker executor per leaf), not a frozen FIFO of the whole tree.
- Keep leaves small and independent — one `.robot` file (plus `__init__.robot` for the folder) is a good leaf. See hub synthetic `smoke/` and `wave2/`.
- Queue selection is a parent standing in for its children. `suiteIds` is an **unordered set**; online LPT picks order. Do not encode run order in directory names or argument files.
- `__init__.robot` holds shared `Test Tags`, Documentation, and Resource imports for that folder. Tests live in sibling `.robot` files, not only in `__init__.robot`.
- Leaves must be `--dryrun`-safe: no browser launch, network, or sleeps in suite setup that would fail catalog collection.
- Prefer `Resource    relative.resource` imports the catalog can resolve from the suite root mount (`/suite`).
- Do not assume pabot or extra `--suite` flags; hub executors already pass `--suite` via a generated `OUT_DIR/rfhub.args`.
