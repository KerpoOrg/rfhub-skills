---
name: rfhub-feedback
description: >-
  Use when the user wants to report a bug, request a feature, or send feedback
  about anything Robot Framework Hub related: rfhub-* skills and mdc, the hub
  UI/API/MCP, orchestrator, catalog, runner, rebot, or deploy. Apply when they
  say "report this to rfhub", "feature request for the orchestrator", "hub
  should…", "bug in rfhub-queue", or "feedback on the hub". Creates a
  structured GitHub issue on KerpoOrg/rfhub-skills for skills-component
  requests and on KerpoOrg/rf-hub for hub-product components. Does not activate
  for kerpo-skills feedback, implementing a fix in the current checkout, or
  issues about the suite repo's own product code.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.1"
---
# rfhub-feedback

> **Access requirement:** the hub product repo is private, so filing hub-product
> issues requires KerpoOrg access. Route by component: `skills` requests go to
> `KerpoOrg/rfhub-skills` (public, where the skills live); `hub`,
> `orchestrator`, `catalog`, `runner`, `rebot`, and `deploy` go to
> `KerpoOrg/rf-hub`. See the package README, "Access requirements".

Sends structured bugs, feature requests, and feedback about **Robot Framework Hub**
to the owning repo — `KerpoOrg/rfhub-skills` for the skills package,
`KerpoOrg/rf-hub` for the hub product, orchestrator, and the rest of the stack.

## When to use

- An `rfhub-*` skill or Cursor rule is wrong, missing, or misfires
- Hub UI, agent/MCP API, ingest, or metrics should change
- Orchestrator, catalog, runner, or rebot behavior / a new capability
- Docs, Compose, or Helm for hub or orch
- General “the hub should…” from a suite repo or from this repo

## Instructions

### Step 1 — Type and component

**Type** (ask if unclear):
- **bug** — incorrect behavior
- **feature-request** — new capability
- **feedback** — usability / improvement, not a concrete bug or spec

**Component** (infer; ask if unclear):

| Component | Examples |
|-----------|----------|
| `skills` | `rfhub-*` skills, `.mdc` / instructions, `packages/rfhub-apm` |
| `hub` | UI, `/api/agent`, MCP, ingest, live, QuestDB metrics |
| `orchestrator` | register, heartbeat, LPT, jobs WebSocket, Play-from-hub |
| `catalog` | dry-run inventory watcher |
| `runner` | batch image, listener, argumentfile, attachments |
| `rebot` | part merge worker |
| `deploy` | Compose / Helm / images |

### Step 2 — Collect context

Ask only what is missing:
- What they were trying to do
- What went wrong or what they want
- For **skills**: skill/instruction name, trigger prompt, package ref
- For **runtime**: hub URL (`:2998` or k3s public URL), orch online?, `project` / `branch`

### Step 3 — Draft

Template for the type: [references/issue-templates.md](references/issue-templates.md).
Fill `## Component`. Show the draft; let them edit.

Title: `[rfhub / {{component}}] {{ short summary }}`

### Step 4 — Create on the owning repo

Route by component from Step 1. Never use the current suite repo `origin`
unless it *is* the target repo.

| Component | Target repo |
|-----------|-------------|
| `skills` | `KerpoOrg/rfhub-skills` |
| `hub`, `orchestrator`, `catalog`, `runner`, `rebot`, `deploy` | `KerpoOrg/rf-hub` |

Ensure type labels (and `rfhub-skills` only when the target is `KerpoOrg/rf-hub`
and component is `skills`):

```bash
gh label create feature-request --repo KerpoOrg/rf-hub \
  --description "New capability" --color a2eeef --force
gh label create feedback --repo KerpoOrg/rf-hub \
  --description "General rfhub feedback" --color d876e3 --force
gh label create rfhub-skills --repo KerpoOrg/rf-hub \
  --description "APM skills / instructions in packages/rfhub-apm" \
  --color 0E8A16 --force
```

Then, using the target repo from the routing table above:

1. **GitHub MCP** — `owner: KerpoOrg`, `repo: rfhub-skills` for `skills`, else `repo: rf-hub`, labels below
2. **gh CLI** — `gh issue create --repo KerpoOrg/<rfhub-skills|rf-hub> --title "..." --body "..." --label <type> [--label rfhub-skills]`

| Type | Labels on `KerpoOrg/rf-hub` | Labels on `KerpoOrg/rfhub-skills` |
|------|-----------------------------|-----------------------------------|
| bug | `bug` + `rfhub-skills` if component is `skills` | `bug` |
| feature-request | `feature-request` + same | `feature-request` |
| feedback | `feedback` + same | `feedback` |

Do not add the `rfhub-skills` label when the target is `KerpoOrg/rfhub-skills`
— it only marks skills-package issues filed on the hub product repo.

Show the issue URL. If MCP and `gh` are unavailable: paste-ready body for
`https://github.com/KerpoOrg/rfhub-skills/issues/new` (`skills`) or
`https://github.com/KerpoOrg/rf-hub/issues/new` (hub-product components).

## Gotchas

- Target is the owning repo (`skills` → `KerpoOrg/rfhub-skills`, hub-product
  components → `KerpoOrg/rf-hub`), never the suite product repo
- `kerpo-skills-feedback` is for `KerpoOrg/kerpo-skills` only
- "Fix the ingest route" / implement in `apps/web` is coding, not this skill — unless they asked to **file** the request
- Type labels: exactly `bug`, `feature-request`, or `feedback`
