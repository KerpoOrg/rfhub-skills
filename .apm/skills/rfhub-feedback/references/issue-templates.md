# Issue templates (rfhub)

Use these templates verbatim. Fill in `{{ }}` placeholders. Remove empty optional sections.

Title: `[rfhub / {{component}}] {{ short summary }}`

`{{component}}` is one of: `skills` | `hub` | `orchestrator` | `catalog` | `runner` | `rebot` | `deploy`

Labels: type (`bug` | `feature-request` | `feedback`); add `rfhub-skills` only
when the target is `KerpoOrg/rf-hub` and component is `skills`.

Target: `skills` → `KerpoOrg/rfhub-skills`; `hub` | `orchestrator` | `catalog` |
`runner` | `rebot` | `deploy` → `KerpoOrg/rf-hub`.

---

## Bug Report (`label: bug`)

```markdown
## Component

`{{component}}`

## Surface

{{ skill name, UI path, API route, image, or "General" }}

## What I was trying to do

{{ one sentence }}

## Expected behavior

{{ what should have happened }}

## Actual behavior

{{ what happened instead }}

## Context

- Where: {{ suite repo / hub repo / unknown }}
- Hub URL: {{ e.g. http://127.0.0.1:2998 or n/a }}
- MCP rf-hub: {{ yes / no / n/a }}
- Skills ref: {{ rfhub-skills/vX.Y.Z or n/a }}
- Trigger / repro: {{ prompt, click path, or command }}

## Additional context

{{ optional: logs, screenshots }}
```

---

## Feature Request (`label: feature-request`)

```markdown
## Component

`{{component}}`

## Surface

{{ skill name, orchestrator, hub UI, MCP, or "New" }}

## Problem / need

{{ what they cannot do today }}

## Proposed solution

{{ what hub / orch / skill should do }}

## Use cases

- {{ use case 1 }}
- {{ use case 2 }}

## Additional context

{{ optional: links, prior art }}
```

---

## Feedback (`label: feedback`)

```markdown
## Component

`{{component}}`

## Surface

{{ skill name or "General" }}

## What works well

{{ specific }}

## What could be improved

{{ specific }}

## Suggestions

{{ optional }}

## Additional context

{{ optional }}
```
