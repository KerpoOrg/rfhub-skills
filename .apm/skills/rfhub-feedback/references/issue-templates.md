# Issue templates (rfhub)

Use these templates verbatim. Fill in `{{ }}` placeholders. Remove empty optional sections.

Title: `[rfhub / {{component}}] {{ short summary }}`

`{{component}}` is one of: `skills` | `hub` | `orchestrator` | `catalog` | `runner` | `rebot` | `deploy`

Labels: type (`bug` | `feature-request` | `feedback`); add `rfhub-skills` only
when the target is `KerpoOrg/rf-hub` and component is `skills`.

Target: `skills` → `KerpoOrg/rfhub-skills`; `hub` | `orchestrator` | `catalog` |
`runner` | `rebot` | `deploy` → `KerpoOrg/rf-hub`.

**Sanitized only.** `KerpoOrg/rfhub-skills` is public; keep hub-product issues
sanitized too unless the author opts in. Every `{{ }}` field below takes
sanitized, generic content — never consumer org/repo names or URLs, product
names, private issue links, hub project display names or `project_id` UUIDs,
worktree/branch paths, or consumer-bound commit SHAs. Use placeholders instead:

- `{{suite-repo}}`, `{{feature-branch}}`, `{{worktree}}` — generic names, not real ones
- `{{environment}}` — a slug like `prod` / `accpt`
- `{{error-or-excerpt}}` — the error text only, stripped of identifying paths
- If a real repro needs private detail, write "repro held in consumer suite;
  available on request" in `## Additional context`.

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

- Where: {{ suite repo / hub repo / unknown }} — sanitized, e.g. `{{suite-repo}}`
- Hub URL: {{ e.g. http://127.0.0.1:2998 or n/a }}
- MCP rf-hub: {{ yes / no / n/a }}
- Skills ref: {{ rfhub-skills/vX.Y.Z or n/a }}
- Trigger / repro: {{ prompt, click path, or command }} — sanitized

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

{{ optional: sanitized links, prior art }}
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
