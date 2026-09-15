---
name: rfhub-use-locks
description: >-
  Use when suites or tests share a fixture that must not run in parallel —
  serialize them with hub-managed locks: declaring a lock domain, tagging
  domain:name[:count], setting scoped caps, or reading the Live locks view
  (force-release, manual hold). Apply when the user says "shared rig" /
  "shared device", "exclusive", "license seats", "tests fight over the same
  user / OTP inbox", "lock domain", "set its cap", "what does
  <domain:name> mean", or asks how orchestrator acquire/release and lease
  heartbeat work. Does not activate for plain
  queueing without locks (including waves, parallelism, and WIP marks even
  when the request mentions queues or tags), failure investigation alone,
  or adding a Gherkin test case / test_id / writing .robot sources alone (use
  rfhub-queue / rfhub-investigate / rfhub-write-*).
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-use-locks

> **Access requirement:** needs a running hub you are authorized on (same as
> **rfhub-queue**). Lock domains, caps, and the Live locks view live on the
> hub — tags alone do nothing without them. See the package README, "Access
> requirements".

Teach suite repos when and how to use **hub-managed locks** so shared fixtures
stop colliding: declare a domain, tag the suites/tests that need it, set a
scoped cap, and read the Live locks view. The orchestrator acquires before a
leaf starts and releases when it finishes.

## When to use

- “These suites share one hardware rig / device — serialize them”
- “We have 5 compiler licenses — never run a 6th consumer at once”
- “Tests fight over the same admin user / OTP inbox”
- “What does `exclusive:adminuser` / `license:compiler-x` mean, and where do caps live?”
- “A lock looks stuck — force-release it / hold it manually”

Not for plain queueing, failure diagnosis, or WIP — those are **rfhub-queue** /
**rfhub-investigate**.

## Instructions

1. **Decide exclusive vs counted.** One holder at a time (`hwsetup:elevator`,
   `exclusive:adminuser`) is cap 1. A pool with N seats
   (`license:compiler-x`, cap 5) is counted. One domain per fixture kind —
   do not reuse `exclusive` for unrelated fixtures.
2. **Declare the domain** (project Settings → Locks, or agent API —
   shapes in [references/locks.md](references/locks.md)). Domains are
   project-scoped (`PUT /api/agent/lock-domains`). If the domain does not
   exist, tags referencing it never acquire anything.
3. **Tag the consumers** with `domain:name[:count]` (`exclusive:adminuser`,
   `license:compiler-x:2`). Put the tag on the leaf suite (`Test Tags`) when
   every case in it needs the fixture; on the case (`[Tags]`) only when part
   of the leaf does. Tags are plain scheduling labels, not identity tags —
   never `suite_id:` / `test_id:` shaped.
4. **Set the scoped cap** (`PUT /api/agent/locks`, or Settings → Locks).
   A `ProjectLock` carries `project` + optional `environment` + optional
   `branch` + `cap`. Most-specific scope wins (project+environment+branch
   beats project+environment beats project). Example: cap 5 globally for
   `license:compiler-x`, cap 1 on `environment: prod` where only one seat
   is reachable.
5. **Queue normally** (`rfhub_queue` with `gitSha`, per **rfhub-queue**).
   The orchestrator acquires the tagged locks before a leaf unit starts;
   units that cannot acquire **wait in queue** — they do not fail. A Redis
   lease backs each hold and the executor heartbeats it; when the part
   finishes (or the lease expires) the slot is released.
6. **Read the Live locks view** (hub Live → locks, or `GET /api/locks`) when
   a batch waits longer than expected: holder run/leaf, waiting queue, lease
   age. `force-release` drops a stuck holder (its executor may still think
   it holds the fixture — re-queue rather than trust its result); `manual
   hold` blocks a fixture for maintenance without editing caps.
7. **Acceptance checklist** before calling the fixture safe: domain exists,
   every consumer tag parses as `domain:name[:count]`, a cap covers each
   project/environment/branch the batch runs in, a contended queue run shows
   waiting (not failures), and release after the run returns the slot.

API/UI shapes and tag grammar: [references/locks.md](references/locks.md).

## Gotchas

- Tags without a declared domain or cap do not serialize anything — contention
  still shows up as failed runs, not lock waits.
- Most-specific scope wins: a narrow cap silently overrides the broad one.
  Read all three scopes before blaming the orchestrator.
- An expired lease looks like a flake (holder died, waiter proceeded, fixture
  state is half-written). Check lease age in the Live view before rerunning.
- `parallelism: serial` serializes **one batch**; locks serialize **across
  batches**. Do not fake cross-batch exclusion with serial.
- Do not model WIP or environments with lock tags — WIP is a Redis mark
  (`rfhub_tag_set`), environments are an orchestrator selection
  (`environment:`). Locks are fixtures, not labels.
