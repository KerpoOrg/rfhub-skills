---
name: rfhub-connect
description: >-
  Use when wiring Cursor or Claude to Robot Framework Hub MCP, setting
  .cursor/mcp.json, Authorization Bearer, HUB_URL, HUB_ACCESS_KEY, or when
  rfhub-dev / rf-hub tools are missing or fail to connect. Apply when the user
  says "connect to the hub", "MCP not working", or "access key". Does not
  activate for queueing/investigating once tools already work.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-connect

> **Access requirement:** this skill only works for users authorized on a
> running hub. You need a hub URL and a Bearer access key from your hub
> operator. The hub MCP has no value without hub access. See the package
> README, "Access requirements".

Point the suite workspace at a **running** hub’s Streamable HTTP MCP. Prefer an
APM-installed remote MCP entry so APM owns install/update/removal of the client
config.

## When to use

- First-time setup in a suite repo
- MCP disconnected, 401, or empty tool list
- User has a key from hub `config/accesskeys.json` and a hub URL

## Instructions

1. Hub must already be up. Local edit loop is `:2998` (`mise run dev`). Production
   hub is `https://rfhub.kerpo.org`. Ask which URL if unknown.
2. Get a Bearer key from the hub host `config/accesskeys.json` (`keys[].key`,
   prefix `rfhub_`). Same key as runners.
3. Preferred: set `RFHUB_MCP_URL` and `RFHUB_ACCESS_KEY`, then install the MCP
   entry with APM's CLI. This is the supported path when the hub URL is not
   known until install time.

```bash
# Local Compose hub (hub developers)
export RFHUB_MCP_URL="http://127.0.0.1:2998/api/mcp"
export RFHUB_ACCESS_KEY="rfhub_..."
apm install --target cursor \
  --mcp rfhub-dev \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "Authorization=Bearer ${RFHUB_ACCESS_KEY}"

# Production hub (suite repos / remote)
export RFHUB_MCP_URL="https://rfhub.kerpo.org/api/mcp"
apm install --target cursor \
  --mcp rf-hub \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "Authorization=Bearer ${RFHUB_ACCESS_KEY}"
```

4. Fallback only when APM is not in use: merge into workspace `.cursor/mcp.json`
   (gitignored on many repos). **Hub repo** typically registers both `rfhub-dev`
   and `rf-hub` (see `mcp/cursor.mcp.json.example`). Suite repos use the hub they
   talk to (local Compose or production).

```json
{
  "mcpServers": {
    "rfhub-dev": {
      "url": "http://127.0.0.1:2998/api/mcp",
      "headers": {
        "Authorization": "Bearer rfhub_…",
        "X-Rfhub-Skills-Version": "0.2.5"
      }
    },
    "rf-hub": {
      "url": "https://rfhub.kerpo.org/api/mcp",
      "headers": {
        "Authorization": "Bearer rfhub_…",
        "X-Rfhub-Skills-Version": "0.2.5"
      }
    }
  }
}
```

| Server | URL | Use when |
|--------|-----|----------|
| `rfhub-dev` | `:2998` | `mise run dev`, Compose UI/orch |
| `rf-hub` | `https://rfhub.kerpo.org` | Production hub (Argo CD / `k3s-kerpo`) |

`X-Rfhub-Skills-Version` must match the installed `rfhub-skills` semver. Hub MCP warns on initialize when it is missing or behind.

Queue, tags, and investigate on the **server that matches that orch’s hub**. Tools are `rfhub_*` on both.

5. Reload MCP in Cursor (**Settings → MCP**). Confirm tools include
   `rfhub_queue`, `rfhub_failures`, `rfhub_metrics_overview`.
6. **Skills version header (required for mismatch warnings):** send
   `X-Rfhub-Skills-Version: <semver>` matching the installed `rfhub-skills`
   pin (from suite `apm.yml` / `packages/rfhub-apm/apm.yml` `version:`). Example
   for this package train: `0.2.5`. MCP `initialize` / `tools/list` return
   `_meta.rfhub/skillsVersionWarning` when the pin is behind the hub — bump
   `ref: rfhub-skills/vX.Y.Z`, run `apm install`, reload MCP. Skills and MCP
   ship together; do not ignore the warning.
7. Optional stdio fallback is hub `mcp/server.mjs` with `HUB_ACCESS_KEY` —
   prefer the HTTP URL.
8. After connect, stop. Queue → `rfhub-queue`. Failures → `rfhub-investigate`.

Details: [references/mcp-json.md](references/mcp-json.md).

## Gotchas

- `127.0.0.1` from a **container** is not the hub host — runners use `host.docker.internal`. MCP in Cursor on the host can use localhost.
- For the `cursor` target, Microsoft APM resolves remote MCP `${VAR}` /
  `${env:VAR}` placeholders at install time. APM still owns add/remove/update,
  but it does **not** keep the Bearer out of Cursor's generated config for a
  remote MCP server today.
- A later plain `apm install` removes undeclared MCP entries. If the remote MCP
  is installed with the CLI command above rather than kept in `apm.yml`, rerun
  the MCP install command after a normal package install.
- Do not copy `mcp/server.mjs` into the suite repo.
- Anonymous hub **UI** does not replace MCP; agent/queue/metrics need the Bearer.
- Missing or stale `X-Rfhub-Skills-Version` → hub warns on initialize; behind pins also prefix `tools/call` content until you update skills.