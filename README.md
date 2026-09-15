# rfhub-skills

Public APM package for suite repos that work with Robot Framework Hub. Skills use
the `rfhub-` prefix. Glob-scoped instructions compile to Cursor `.mdc` (and Claude
rules) so agents do not have to guess hub tags, leaf layout, or failure
attachments.

## Access requirements

Robot Framework Hub is not a public service. This package is published so the
skills and Robot authoring conventions can be reused, but most hub-facing skills
only work if you are connected to a **running hub you are authorized to use**:

| You have | Most skills work? |
|----------|-------------------|
| Hub URL + an account that can log in (MCP OAuth) | Yes — MCP, queue, investigate, feedback |
| Hub access + runner image access | Yes, including `rfhub-write-pythonkeyword` / `rfhub-write-argumentfile` |
| Only Robot authoring needs | Partially — the `rfhub-write-*` skills and the always-on instructions stand alone; anything driving MCP/queue/metrics does not |

The `rfhub-connect`, `rfhub-queue`, `rfhub-investigate`, and `rfhub-feedback`
skills are **non-functional without hub access**. The hub MCP has
no value to anyone who cannot reach a hub. The runner image referenced by the
Python-keyword and argumentfile skills is served from a private registry today
(`harbor.kerpo.org/library-private/...`) and will move to a public
`library/rf-hub-runner` later; treat those references as "provided by your hub
operator".

## Install

Installing with [APM](https://github.com/microsoft/apm) is the default — it
fetches a pinned tag from this repo and never needs a source checkout. Clone the
repo only if you want to modify the skills, instructions, or evals (see
[Develop from source](#develop-from-source)).

### Global (recommended)

Install once per machine into `~/.apm/` — agents in any workspace get the skills,
with nothing to check out or commit:

```bash
apm install -g KerpoOrg/rfhub-skills#v0.7.0
apm compile -g   # refresh harness root context (e.g. opencode)
```

The `#vX.Y.Z` selector is required; without it APM tracks the branch and warns
about drift. Global scope fully supports claude, opencode, agent-skills, and
others; Cursor instruction rules (`.mdc`) are only fully supported at project
scope, so use the project install below when a specific repo needs them.

### Project-scoped (skills + Cursor rules pinned per repo)

Use this when a suite repo should commit the pin and get the Cursor rules.

**1. Add to the repo's `mise.toml`:**

```toml
[tools]
"github:microsoft/apm" = "0.30.0"
```

**2. Add the APM dependency** in `apm.yml`:

```yaml
dependencies:
  apm:
    - git: https://github.com/KerpoOrg/rfhub-skills.git
      ref: v0.7.0
```

Pin `ref` to a `vX.Y.Z` tag (see [Versioning](#versioning)). Equivalent short form
if your APM accepts `owner/repo#tag`: `KerpoOrg/rfhub-skills#v0.7.0`.

**3. Install:**

```bash
apm install
```

Skills land in `.agents/skills/`. Instructions compile to `.cursor/rules/*.mdc`
(Cursor) and `.claude/rules/` (Claude). The declared hub MCP is written to each
harness's MCP config (`.mcp.json`, `.cursor/mcp.json`). Commit `apm.yml` and
`apm.lock.yaml`. Gitignore generated `.agents/skills/`,
`.cursor/rules/rfhub-*.mdc`, `.mcp.json`, and `.cursor/mcp.json`.

## Set up the hub MCP (requires hub access)

The package declares the standard hub MCP (`rf-hub`) as an APM MCP dependency,
so installing the skills wires the MCP in the same step. The hub is its own
OAuth Authorization Server: the client discovers the flow from the
unauthenticated `401` + `resource_metadata` on `POST /api/mcp`, so no static
token is stored.

### One-command connect (standard hub)

```bash
apm install -g KerpoOrg/rfhub-skills#v0.7.0
apm compile -g   # refresh harness root context (e.g. opencode)
```

Project-scoped installs (see [Install](#install)) do the same: `apm install`
writes `rf-hub` into every detected harness from the package's
`dependencies.mcp`. Commit `apm.yml` and `apm.lock.yaml` and the MCP wiring stays
reproducible for teammates and CI.

On first connect the client opens the hub authorize URL in a browser — log in
with Pocket ID (you must be in the hub's allowed group) and consent. The result
is a 30-day app token (`agent` + `mcp` scope) you can revoke any time in the hub
**Settings → API Keys**.

### Self-hosted or non-standard hub

The declared URL is the standard `https://rfhub.kerpo.org/api/mcp`. APM requires
a literal `http(s)` remote `url:` and expands `${VAR}` only in `headers:` and
`env:` (not `url:`), so the manifest cannot carry a per-user URL. Override it by
declaring `rf-hub` in your repo's own `apm.yml`; your entry wins over the
package copy:

```yaml
dependencies:
  mcp:
    - name: rf-hub
      registry: false
      transport: http
      url: "https://<your-hub-host>/api/mcp"
      headers:
        X-Rfhub-Skills-Version: "0.7.0"
```

Or let APM write that entry for you:

```bash
export RFHUB_MCP_URL="https://<your-hub-host>/api/mcp"
apm install --target claude,cursor \
  --mcp rf-hub \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "X-Rfhub-Skills-Version=0.7.0"
```

Hub developers running the Compose hub get `rfhub-dev`
(`http://127.0.0.1:2998/api/mcp`) from the package's `devDependencies`: a plain
`apm install` in this repo wires it, and `apm install` of this package as a
dependency excludes devDependencies, so suite repos do not receive it.

### Trust boundary for self-defined MCP servers

`rf-hub` is a **self-defined** server (`registry: false`). APM trusts it only
when this package is a **direct** dependency. If `rfhub-skills` is pulled in
transitively, APM warns and skips the entry unless the consumer passes
`--trust-transitive-mcp` or re-declares `rf-hub` in their own `apm.yml`. See
APM's
[MCP as a primitive](https://microsoft.github.io/apm/producer/author-primitives/mcp-as-primitive/#direct-vs-transitive-the-trust-boundary).

Manual fallback (clients without MCP OAuth, or scripted setups): mint a key under
the hub **Settings → API Keys** (preset “MCP / Agent”) and send it as an
`Authorization: Bearer` header:

```bash
apm install --target claude,cursor \
  --mcp rf-hub \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "Authorization=Bearer ${RFHUB_ACCESS_KEY}" \
  --header "X-Rfhub-Skills-Version=0.7.0"
```

APM owns the MCP entry in client config after that. Re-run the install when the
URL or method changes; a later plain `apm install` removes MCP entries that are
not declared in `apm.yml`.

## Robot language server (optional, Claude Code / Copilot CLI only)

This package declares a Robot Framework language server so editors with LSP
support surface undefined keywords, syntax errors, and bad imports **before** a
hub run burns queue time:

```yaml
dependencies:
  lsp:
    - name: robotcode
      command: robotcode
      args: ["language-server", "--stdio"]
      extensionToLanguage:
        ".robot": robotframework
        ".resource": robotframework
      transport: stdio
```

APM writes the runtime config but does **not** install the server binary.
Install it separately and make sure `robotcode` is on `PATH`:

```bash
pip install "robotcode[languageserver]"
robotcode language-server --help   # `--stdio` is the default mode
```

Notes:

- Language id `robotframework` with `.robot` / `.resource` matches RobotCode's
  VS Code `contributes.languages` mapping.
- `transport: stdio` matches the server default (`--mode STDIO`); `--stdio` is
  passed explicitly so the intent survives future default changes.
- APM LSP wiring today targets **Claude Code and GitHub Copilot CLI only** —
  not Cursor or OpenCode. This is additive for Claude users, not a universal
  feature and not a hard requirement for hub authoring.
- When the executables gate is enabled, transitive consumers approve with
  `apm approve KerpoOrg/rfhub-skills`; root-project declarations are trusted as
  local content. Removing the declaration cleans the server up automatically.

## What you get

| Kind | Name | When |
|------|------|------|
| Skill | `rfhub` | Map: which hub workflow to run |
| Skill | `rfhub-connect` | MCP URL + OAuth login |
| Skill | `rfhub-queue` | Queue suites / poll a batch |
| Skill | `rfhub-investigate` | Failures, logs, flake, metrics |
| Skill | `rfhub-fixloop` | Iterative fix → rerun → verify until green |
| Skill | `rfhub-atdd` | Acceptance-test-first double loop: red on hub → TDD → green; delivery wording sets the horizon |
| Skill | `rfhub-use-locks` | Shared-fixture lock domains, tags, caps, Live view |
| Skill | `rfhub-feedback` | Bugs / features / feedback on hub, orch, skills, runner |
| Skill | `rfhub-write-argumentfile` | Robot `*.args` |
| Skill | `rfhub-write-acceptance` | Acceptance definition (ordered waves as criteria) |
| Skill | `rfhub-write-suite` | Leaf suite / `__init__.robot` |
| Skill | `rfhub-write-testcase` | One Gherkin test case |
| Skill | `rfhub-write-suitekeyword` | Keywords in the same `.robot` |
| Skill | `rfhub-write-resourcekeyword` | Shared `*.resource` |
| Skill | `rfhub-write-pythonkeyword` | Python library keywords |
| Instruction | `rfhub-stable-ids` | `project_id` / `suite_id` / `test_id` on `*.robot` / `*.resource` |
| Instruction | `rfhub-tag-placement` | Promote/demote shared tags; suite-level WIP |
| Instruction | `rfhub-gherkin` | Given/When/Then cases; keywords implement how |
| Instruction | `rfhub-leaf-suites` | Catalog/orchestrator leaf layout |
| Instruction | `rfhub-failure-evidence` | Attachment paths in FAIL messages |

## Develop from source

Only for changing this package. Regular consumers install with APM above. Clone
the repo, then:

```bash
# Create a new skill
./scripts/new-skill.sh rfhub-write-example

# Validate
apm audit --file .apm/skills/rfhub-write-example/SKILL.md

# Preview Cursor deploy without writing
apm install --dry-run --target cursor

# Trigger accuracy + output-quality evals (free OpenCode model)
mise run skills -- triggers
mise run skills -- evals
```

Evals run a free OpenCode Zen model in an isolated project — no Claude or paid
API key. See [docs/evals.md](docs/evals.md) for prerequisites
(`opencode auth login`), the `EVAL_MODEL` override, and result layout.

## Repo structure

```
.apm/skills/rfhub-<name>/
├── SKILL.md
├── references/          # loaded on demand
└── evals/
    ├── evals.json
    └── eval_queries.json
.apm/instructions/
└── rfhub-*.instructions.md   # source; APM compiles to .mdc
```

## Versioning

This package is versioned independently of the Robot Framework Hub product.

| Piece | Where |
|-------|--------|
| SemVer string | `apm.yml` → `version:` |
| Git tag consumers pin | `vX.Y.Z` on `KerpoOrg/rfhub-skills` (annotated tag on the commit that bumped `version:`) |
| Lock | consumer `apm.lock.yaml` (commit SHA + content hashes) |

**When to bump**

- **patch** (`0.1.0` → `0.1.1`) — wording, examples, gotchas; same skill names and MCP contracts
- **minor** (`0.1.0` → `0.2.0`) — new skill or instruction; existing triggers still work
- **major** (`0.x` → `1.0.0`, later `1.x` → `2.0.0`) — renamed/removed skill, changed identity-tag rules, or a queue/MCP workflow that would mis-train agents on old instructions

**Release**

Cut versions with the manual workflow: **Actions → Release → Run workflow**
(choose `patch` / `minor` / `major`, or an explicit `version`; enable `dry_run` to
preview). It bumps `apm.yml` and the version references, commits to the default
branch, creates the annotated `vX.Y.Z` tag, and opens the GitHub Release.

After releasing, sync the hub product repo's expected skills semver
(`apps/web/skills-package.version` in `KerpoOrg/rf-hub`) when the MCP contract
changes — the hub warns consumers whose installed skills are behind. Consumers
change `ref:` and run `apm install`, and set the MCP header
`X-Rfhub-Skills-Version` to the new semver.

## Server name / header conventions

- MCP server name is `rf-hub` for a deployed hub; hub developers may use `rfhub-dev` for Compose.
- `X-Rfhub-Skills-Version` must match the installed `rfhub-skills` semver. Hub MCP warns on initialize when it is missing or behind.

## License

MIT — see [LICENSE](LICENSE).
