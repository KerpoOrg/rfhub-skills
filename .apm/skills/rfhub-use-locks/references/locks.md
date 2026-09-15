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

## Scoped caps

```http
PUT /api/agent/locks
{
  "project": "<id|name>",
  "domain": "license",
  "name": "compiler-x",
  "cap": 5,
  "environment": "prod",
  "branch": "main"
}
```

- `environment` and `branch` are optional. Most-specific scope wins:
  project+environment+branch > project+environment > project.
- Typical split: broad cap for the pool, narrow override where fewer seats
  are reachable (e.g. cap 5 globally, cap 1 on `environment: prod`).
- UI: project → Settings → Locks shows effective caps per scope.

## Runtime behavior

- The orchestrator acquires all tagged locks before a leaf unit starts.
  Units that cannot acquire **wait in queue**; they do not fail.
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
