---
name: rfhub-connect
description: >-
  Use when wiring Cursor or Claude to Robot Framework Hub MCP, setting
  .cursor/mcp.json, MCP OAuth login, or when rfhub-dev / rf-hub tools are
  missing or fail to connect. Apply when the user says "connect to the hub",
  "MCP not working", or "log in to MCP". Does not activate for queueing or
  investigating once tools already work.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "2.0"
---
# rfhub-connect

> **Access requirement:** this skill only works for users authorized on a
> running hub. You need a hub URL and an account in the hub's allowed group;
> MCP auth is OAuth (a manual API key is the exception). The hub MCP has no
> value without hub access. See the package README, "Access requirements".

Point the suite workspace at a **running** hub’s Streamable HTTP MCP. The hub is
its own OAuth Authorization Server, so the client logs in with Pocket ID — no
static Bearer key needed.

## When to use

- First-time setup in a suite repo
- MCP disconnected, 401, or empty tool list
- User asks how to authenticate MCP (OAuth)

## Instructions

1. Hub must already be up. Production hub is `https://rfhub.kerpo.org`. Hub
   developers use the Compose hub at `http://127.0.0.1:2998`. Ask which URL if
   unknown.
2. Preferred: the package declares `rf-hub` as a self-defined remote MCP server
   in `apm.yml`, so installing the skills wires it. A plain `apm install` is
   enough; the client discovers OAuth from the unauthenticated `401` +
   `WWW-Authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource"`
   and starts the login flow.

```bash
apm install -g KerpoOrg/rfhub-skills#v0.4.1
apm compile -g   # refresh harness root context (e.g. opencode)
```

3. Non-standard or self-hosted hub: override the declared URL. APM requires a
   literal `http(s)` `url:` and does not expand `${VAR}` in `url:`, so declare
   `rf-hub` in the repo's own `apm.yml` (your entry wins), or let APM write it:

```bash
export RFHUB_MCP_URL="https://<your-hub-host>/api/mcp"
apm install --target claude,cursor \
  --mcp rf-hub \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "X-Rfhub-Skills-Version=0.4.1"
```

```yaml
dependencies:
  mcp:
    - name: rf-hub
      registry: false
      transport: http
      url: "https://<your-hub-host>/api/mcp"
      headers:
        X-Rfhub-Skills-Version: "0.4.1"
```

   `rf-hub` is self-defined, so APM trusts it only when `rfhub-skills` is a
   direct dependency. Transitive consumers get a warning and skip unless they
   pass `--trust-transitive-mcp` or re-declare `rf-hub` themselves.

   Hub developers get `rfhub-dev` (`http://127.0.0.1:2998/api/mcp`) from this
   package's `devDependencies`; a plain `apm install` in the package repo wires
   it.

4. First connect opens the hub authorize URL in a browser — log in with Pocket
   ID (must be in the hub's allowed group), then consent. The client receives a
   30-day app token (`agent` + `mcp` scope) owned by that account. It appears in
   the hub **Settings → API Keys** with an `OAuth` badge and can be revoked
   there. Expired tokens simply log in again.

5. Manual fallback (clients without MCP OAuth, or scripted setups): mint a key
   under **Settings → API Keys** (preset “MCP / Agent”, 30-day expiry) and send
   it as `Authorization: Bearer`. With APM that is an explicit header:

```bash
apm install --target claude,cursor \
  --mcp rf-hub \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "Authorization=Bearer ${RFHUB_ACCESS_KEY}" \
  --header "X-Rfhub-Skills-Version=0.4.1"
```

6. Fallback only when APM is not in use: merge into workspace `.cursor/mcp.json`
   (gitignored on many repos). OAuth needs no `Authorization` — the client fills
   it after login; the manual key adds one.

```json
{
  "mcpServers": {
    "rf-hub": {
      "url": "https://rfhub.kerpo.org/api/mcp",
      "headers": {
        "X-Rfhub-Skills-Version": "0.4.1"
      }
    }
  }
}
```

   Manual-key variant adds `"Authorization": "Bearer rfhub_…"` to `headers`.

| Server | URL | Use when |
|--------|-----|----------|
| `rfhub-dev` | `:2998` | `mise run dev`, Compose UI/orch (package `devDependencies`) |
| `rf-hub` | `https://rfhub.kerpo.org` | Production hub (Argo CD / `k3s-kerpo`) |

7. Reload MCP in Cursor (**Settings → MCP**). Confirm tools include
   `rfhub_queue`, `rfhub_failures`, `rfhub_metrics_overview`.
8. **Skills version header (required for mismatch warnings):** send
   `X-Rfhub-Skills-Version: <semver>` matching the installed `rfhub-skills`
   pin (from suite `apm.yml` / package `version:`). Example for this package
   train: `0.4.1`. MCP `initialize` / `tools/list` return
   `_meta.rfhub/skillsVersionWarning` when the pin is behind the hub — bump
   `ref: vX.Y.Z` (KerpoOrg/rfhub-skills), run `apm install`, reload MCP.
   Skills and MCP ship together; do not ignore the warning.
9. Optional stdio fallback is hub `mcp/server.mjs` with `HUB_ACCESS_KEY` —
   prefer the HTTP URL.
10. After connect, stop. Queue → `rfhub-queue`. Failures → `rfhub-investigate`.

Details: [references/mcp-json.md](references/mcp-json.md).

## Gotchas

- `127.0.0.1` from a **container** is not the hub host — runners use `host.docker.internal`. MCP in Cursor on the host can use localhost.
- OAuth app tokens are Bearer tokens under the hood; `X-Rfhub-Skills-Version` is still required as a separate header.
- A plain `apm install` reconciles declared MCP entries: the package's `rf-hub` (or your override in `apm.yml`) survives, while undeclared MCP entries are removed. Keep an override in `apm.yml` so it is not dropped.
- Do not copy `mcp/server.mjs` into the suite repo.
- Anonymous hub **UI** does not replace MCP; agent/queue/metrics need an authenticated session or token.
- Missing or stale `X-Rfhub-Skills-Version` → hub warns on initialize; behind pins also prefix `tools/call` content until you update skills.
