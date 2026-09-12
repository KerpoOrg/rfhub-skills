# Cursor MCP snippet

Hub serves MCP at `POST {HUB_URL}/api/mcp`. Suite workspaces do not copy a server file.

| Server (Cursor name) | Hub you started | URL |
|----------------------|-----------------|-----|
| `rfhub-dev` | `mise run dev` (Compose) | `http://127.0.0.1:2998/api/mcp` |
| `rf-hub` | Production (Argo CD / `k3s-kerpo`) | `https://rfhub.kerpo.org/api/mcp` |
| (one entry, any name) | Remote / LAN | `https://<hub-host>/api/mcp` (TLS in production) |

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
        "Authorization": "Bearer rfhub_replace_with_key_from_config_accesskeys_json",
        "X-Rfhub-Skills-Version": "0.2.5"
      }
    },
    "rf-hub": {
      "url": "https://rfhub.kerpo.org/api/mcp",
      "headers": {
        "Authorization": "Bearer rfhub_replace_with_key_from_config_accesskeys_json",
        "X-Rfhub-Skills-Version": "0.2.5"
      }
    }
  }
}
```

Smoke without Cursor:

```bash
curl -s -H "Authorization: Bearer $KEY" "$HUB_URL/api/agent" | head
```

401 → wrong or missing key. Connection error → hub not running or wrong port.
