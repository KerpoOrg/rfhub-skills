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
| Hub URL + Bearer access key | Yes — MCP, queue, investigate, feedback |
| Hub access + runner image access | Yes, including `rfhub-write-pythonkeyword` / `rfhub-write-argumentfile` |
| Only Robot authoring needs | Partially — the `rfhub-write-*` skills and the always-on instructions stand alone; anything driving MCP/queue/metrics does not |

The `rfhub-connect`, `rfhub-queue`, `rfhub-investigate`, and `rfhub-feedback`
skills are **non-functional without hub access and a Bearer key**. The hub MCP has
no value to anyone who cannot reach a hub. The runner image referenced by the
Python-keyword and argumentfile skills is served from a private registry today
(`harbor.kerpo.org/library-private/...`) and will move to a public
`library/rf-hub-runner` later; treat those references as "provided by your hub
operator".

## Install in your suite repo

Requires [mise](https://mise.jdx.dev) and [gh](https://cli.github.com) (only for
hub access; installing this package does not need KerpoOrg SSH access, since this
repo is public).

**1. Add to your project's `mise.toml`:**

```toml
[tools]
"github:microsoft/apm" = "0.30.0"
```

**2. Add the APM dependency** in the suite repo's `apm.yml`:

```yaml
dependencies:
  apm:
    - git: https://github.com/KerpoOrg/rfhub-skills.git
      ref: v0.2.5
```

Pin `ref` to a `vX.Y.Z` tag (see [Versioning](#versioning)). Equivalent short form
if your APM accepts `owner/repo#tag`: `KerpoOrg/rfhub-skills#v0.2.5`.

**3. Install:**

```bash
apm install
```

Skills land in `.agents/skills/`. Instructions compile to `.cursor/rules/*.mdc`
(Cursor) and `.claude/rules/` (Claude). Commit `apm.yml` and `apm.lock.yaml`.
Gitignore generated `.agents/skills/` and `.cursor/rules/rfhub-*.mdc`.

## Set up the hub MCP (requires hub access)

Install the skills package with `apm install`, then add the remote MCP entry with
APM's CLI. This is the supported pattern when the hub URL is only known at install
time, because Microsoft APM requires a literal remote `url:` in package manifests.

```bash
export RFHUB_MCP_URL="https://<your-hub-host>/api/mcp"
export RFHUB_ACCESS_KEY="rfhub_..."
apm install --target cursor \
  --mcp rf-hub \
  --transport http \
  --url "$RFHUB_MCP_URL" \
  --header "Authorization=Bearer ${RFHUB_ACCESS_KEY}"
```

Hub developers running the Compose hub use `RFHUB_MCP_URL="http://127.0.0.1:2998/api/mcp"`
and the server name `rfhub-dev`.

APM owns the MCP entry in client config after that. Re-run the same install
command when the URL or auth changes. A later plain `apm install` removes
undeclared MCP entries, so if your project does not keep the MCP in its manifest
you must re-run the MCP install step after a normal package install.

For the `cursor` target specifically, Microsoft APM resolves `${VAR}` /
`${env:VAR}` in remote MCP config at install time, so Cursor still ends up with
concrete values in its generated MCP config. APM helps with install, upgrade, and
removal, but does **not** keep the Bearer out of Cursor config for remote MCP
today.

## What you get

| Kind | Name | When |
|------|------|------|
| Skill | `rfhub` | Map: which hub workflow to run |
| Skill | `rfhub-connect` | MCP URL + Bearer |
| Skill | `rfhub-queue` | Queue suites / poll a batch |
| Skill | `rfhub-investigate` | Failures, logs, flake, metrics |
| Skill | `rfhub-feedback` | Bugs / features / feedback on hub, orch, skills, runner |
| Skill | `rfhub-write-argumentfile` | Robot `*.args` |
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

## Quick start (this package)

```bash
# Create a new skill
./scripts/new-skill.sh rfhub-write-example

# Validate
apm audit --file .apm/skills/rfhub-write-example/SKILL.md

# Preview Cursor deploy without writing
apm install --dry-run --target cursor
```

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

1. Bump `version:` in `apm.yml` (and this README's `ref:` example).
2. Keep the hub MCP's expected skills semver in sync when shipping MCP contract changes.
3. Commit, then `git tag -a vX.Y.Z -m "rfhub-skills X.Y.Z"` and push the tag.
4. Consumers change `ref:` and run `apm install`. Set the MCP header
   `X-Rfhub-Skills-Version` to the new semver so the hub does not warn.

## Server name / header conventions

- MCP server name is `rf-hub` for a deployed hub; hub developers may use `rfhub-dev` for Compose.
- `X-Rfhub-Skills-Version` must match the installed `rfhub-skills` semver. Hub MCP warns on initialize when it is missing or behind.

## License

MIT — see [LICENSE](LICENSE).
