# Locks: domains, tags, caps, live view

Tag grammar (scheduling labels, not identity tags):

```robot
*** Settings ***
Test Tags    license:compiler-x       # whole leaf needs one seat
```

```robot
Exclusive Rig
    [Tags]    hwsetup:elevator        # cap 1 — one holder at a time
    Given rig is reserved
```

- Shape: `domain:name[:count]` — `exclusive:adminuser`,
  `license:compiler-x`, `license:compiler-x:2` (takes two seats).
- Suite-level (`Test Tags`) when every case needs the fixture; case-level
  (`[Tags]`) only for partial use. Never `suite_id:` / `test_id:` shaped.

## Domains

Project-scoped. Create once per fixture kind (hub UI: project → Settings →
Locks, or agent API):

```http
PUT /api/agent/lock-domains
{ "project": "<id|name>", "domain": "license", "title": "Compiler seats" }
```

Queueing a tag whose domain does not exist acquires nothing — the suite just
runs unserialized.

## Lock scope and caps

```http
PUT /api/agent/locks
{
  "project": "<id|name>",
  "domain": "license",
  "name": "compiler-x",
  "cap": 5,
  "scope": "project"
}
```

- `scope` is a single choice — how widely the seat pool is shared:
  - `project` (default): every orchestrator of the project shares one pool;
  - `environment`: each environment (dev / accpt / prod) gets its own pool;
  - `branch`: orchestrators working on the same branch share a pool;
  - `run`: only units of the same run contend — two different runs never
    block each other.
- One cap per lock: every bucket of a scoped lock gets the full cap.
- The old independent `environment` / `branch` fields are gone (RFHUB-12) —
  `PUT` rejects them with a 400. No more per-environment cap overrides.
- UI: project → Settings → Locks shows the scope per lock; the Live locks
  view shows one row per held bucket (`env:dev`, `branch:main`, …).

## Runtime behavior

- The orchestrator acquires all tagged locks before a leaf unit starts.
  Units that cannot acquire **wait in queue**; they do not fail.
- Capacity is counted per scope bucket. A run-scoped lock never blocks
  another run; an environment-scoped lock never blocks a different
  environment.
- Each hold is a Redis lease; the executor heartbeats it while the unit
  runs. Finish (or lease expiry) releases the slot.
- A dead holder (expired lease, executor gone) frees the slot but may leave
  the fixture half-written — verify fixture state before trusting the next
  result.

## Live locks view

```http
GET /api/locks?project=<id|name>   → holders, waiters, lease ages
```

Hub UI: Live → locks. `force-release` drops a stuck holder (do not trust
that executor's result — re-queue); `manual hold` parks a fixture for
maintenance without touching caps.
