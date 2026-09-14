# Cursor MCP snippet

Hub serves MCP at `POST {HUB_URL}/api/mcp`. Suite workspaces do not copy a server file.

The package declares `rf-hub` (`https://rfhub.kerpo.org/api/mcp`) under
`dependencies.mcp`, so `apm install` writes it to the harness — no hand-editing.
`rfhub-dev` (Compose) comes from the package's `devDependencies` (root install
only; `apm install` of the package as a dependency excludes it). APM expands
`${VAR}` only in `headers:`/`env:`, not `url:`, so a self-hosted hub overrides
`rf-hub` in its own `apm.yml` (the root entry wins) or with
`apm install --mcp rf-hub --transport http --url "$RFHUB_MCP_URL"`. `rf-hub` is
self-defined (`registry: false`): APM trusts it only for a direct dependency;
transitive consumers get a warning and skip unless they pass
`--trust-transitive-mcp`.

| Server (Cursor name) | Hub you started | URL |
|----------------------|-----------------|-----|
| `rfhub-dev` | `mise run dev` (Compose) | `http://127.0.0.1:2998/api/mcp` |
| `rf-hub` | Production (Argo CD / `k3s-kerpo`) | `https://rfhub.kerpo.org/api/mcp` |
| (one entry, any name) | Remote / LAN | `https://<hub-host>/api/mcp` (TLS in production) |

The hub is its own OAuth Authorization Server. An unauthenticated `POST /api/mcp`
returns `401` with
`WWW-Authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource"`,
so a spec-compliant client discovers the flow and logs in with Pocket ID — no
static token in the config:

1. Client registers via `POST /oauth/register`.
2. Browser opens `GET /oauth/authorize` — log in with Pocket ID (must be in the
   hub's allowed group) and consent.
3. Client exchanges the code at `POST /oauth/token` (PKCE `S256`) for a 30-day
   `agent`+`mcp` app token, revocable in the hub **Settings → API Keys**.

Manual fallback (client without MCP OAuth): mint a key in the hub
**Settings → API Keys** (preset “MCP / Agent”) and add it as an
`Authorization: Bearer` header.

In the **hub repo**, register both `rfhub-dev` (Compose edit loop) and `rf-hub`
(production) — see `mcp/cursor.mcp.json.example`. Suite repos that talk to
production use `rf-hub` pointed at `https://rfhub.kerpo.org/api/mcp`. Call tools
on the server that matches the hub the orchestrator posts to.

Send `X-Rfhub-Skills-Version` with the installed `rfhub-skills` semver (same as
`apm.yml` / package `version:`). Hub MCP initialize warns when it is missing or
behind — bump the skills pin and `apm install`.

```json
{
  "mcpServers": {
    "rfhub-dev": {
      "url": "http://127.0.0.1:2998/api/mcp",
      "headers": {
        "X-Rfhub-Skills-Version": "0.5.1"
      }
    },
    "rf-hub": {
      "url": "https://rfhub.kerpo.org/api/mcp",
      "headers": {
        "X-Rfhub-Skills-Version": "0.5.1"
      }
    }
  }
}
```

Add `"Authorization": "Bearer rfhub_…"` to a server's `headers` only when using
the manual API-key fallback; OAuth clients fill that in themselves.

Smoke without Cursor (key minted in **Settings → API Keys**):

```bash
curl -s -H "Authorization: Bearer $KEY" "$HUB_URL/api/agent" | head
```

401 → not logged in / wrong or missing key. Connection error → hub not running
or wrong port.
