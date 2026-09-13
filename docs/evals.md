# Skill evals (local)

Two harnesses, both driven by a **free OpenCode model** instead of Claude:

| Harness | Script | Question it answers |
|---|---|---|
| Trigger accuracy | `scripts/test-triggers.sh` | Does `SKILL.md`'s `description` fire on the right prompts? |
| Output quality | `scripts/run-evals.sh` | With the skill loaded, is the work better than without it? |

They run an isolated OpenCode instance per case, so they are hermetic and safe
to run locally (and, later, in CI).

## Prerequisites

```bash
mise install                 # installs jq, shellcheck, bats, and opencode (pinned)
opencode auth login          # sign in to OpenCode Zen once
opencode models | grep free  # pick a current free model id
```

The pinned OpenCode version is in `mise.toml`; the JSON event shape the harness
parses is tied to that version.

Auth is a single credential in `~/.local/share/opencode/auth.json`. You do not
need an Anthropic/Claude key. A free model costs $0 per request.

## Commands

```bash
# All skills (from .mise/tasks/skills)
mise run skills -- triggers
mise run skills -- evals

# One skill
./scripts/test-triggers.sh rfhub-write-testcase        # runs=3 by default
./scripts/run-evals.sh     rfhub-write-testcase 1      # iteration 1
```

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `EVAL_MODEL` | `opencode/muse-spark-1.3-contributor-free` | `provider/model` to run |
| `EVAL_TIMEOUT` | `180` | Per-call wall-clock seconds (if `timeout` exists) |
| `EVAL_OPENCODE_BIN` | `opencode` | Binary to invoke |

Example:

```bash
EVAL_MODEL=opencode/mimo-v2.5-free \
  ./scripts/test-triggers.sh rfhub-write-subcase
```

Run `opencode models --verbose` and take any entry whose `cost.input` and
`cost.output` are both `0`.

### Choosing a model

Free models differ a lot in how sharply they judge a near-miss. Measured on
`rfhub-write-testcase` (7 queries, 1 run each, 2026-09):

| Model | Trigger score | Notes |
|---|---|---|
| `opencode/muse-spark-1.3-contributor-free` | **6/7** | default; contributor tier |
| `opencode/mimo-v2.5-free` | 4/7 | generic, portable fallback |
| `opencode/big-pickle` | 4/7 | fastest; stealth model |

`muse-spark-1.3-contributor-free` is a Meta **contributor** tier: using it
consents to prompts/completions being used to train Meta models, and it needs a
contributor-enabled Zen account. For a privacy-sensitive run use
`mimo-v2.5-free` (also trains on data during its free period, but no
contributor gate).

## How it works

For every LLM call the harness creates a throwaway project directory and runs:

```bash
opencode run "<prompt>" --pure --model "$EVAL_MODEL" --format json --auto
```

The generated `opencode.json` makes the run hermetic:

- **Skill isolation** — `permission.skill` denies `*` and (for the
  *with skill* case) allows exactly the skill under test. Global and
  sibling skills are hidden, so `without_skill` really has no skill to load.
  The skill itself is copied into `.opencode/skills/<name>/`.
- **Tool lockdown** — every tool except `skill` is disabled. Without this the
  agent wanders the surrounding checkout (and can hang); with it, a run only
  ever loads a skill and writes prose.
- **MCP off** — any MCP server in your global config is disabled for the run.
- **`--pure`** — external plugins are skipped.

Results are parsed from the JSON event stream:

- skill fired → `{"type":"tool_use","part":{"tool":"skill",
  "state":{"input":{"name":"<skill>"}}}}`
- response text → joined `{"type":"text","part":{"text":...}}`
- tokens/cost → summed `{"type":"step_finish","part":{"tokens",...}}`
- grading JSON → the first `{...}` object in the response (code fences stripped)

## Reading results

```
.apm/skills/<skill>/evals/trigger-results.json      # trigger pass/fail per query
<skill>-workspace/iteration-N/
├── eval-<slug>/with_skill/                         # response.txt, timing.json, grading.json
├── eval-<slug>/without_skill/
└── benchmark.json                                   # mean pass-rate + token delta
```

`*.events.json` and `opencode.log` next to each response are the raw model
events and stderr, kept for debugging.

## Iteration loop

1. Run evals → inspect `response.txt` and `timing.json`.
2. Add assertions to `evals.json` only after seeing the first outputs.
3. Feed signals + `SKILL.md` to the agent → tighten `SKILL.md`.
4. Run the next iteration → compare `benchmark.json` delta.
5. Stop when improvement plateaus.

## Caveats

- **Model-dependent numbers.** Trigger/output rates belong to the model that
  produced them. Do not compare a free-model run against old Claude-haiku
  results; re-baseline per skill and per model.
- **Free models change.** They are "for a limited time" and can be retired or
  rate-limited. Keep `EVAL_MODEL` overridable and re-run `opencode models` when
  a model disappears.
- **Privacy.** Free Zen models may log prompts and, for some
  (`big-pickle`, `mimo-v2.5-free`, the contributor tier), use them for
  training. Skill descriptions and eval prompts are package-public; do not put
  secrets or customer data in them.
- **Speed.** Some free models are minutes-slow (`nemotron-*`, `ling-*`).
  Prefer `mimo-v2.5-free` / `muse-spark-1.3-contributor-free`; `EVAL_TIMEOUT`
  bounds each call (exit code 124).
- **Judge quality.** `run-evals.sh` grades with the same free model, so
  assertions are only as good as that judge. Keep assertions concrete and
  re-check grading JSON when a score looks wrong.

## CI

`.github/workflows/skills-evals.yml` runs the trigger evals nightly (03:17 UTC)
and on `workflow_dispatch`:

- **Auth** — `OPENCODE_API_KEY` secret. Free Zen models also work without it,
  under anonymous rate limits; when the secret is unset the step unsets the
  variable so the model runs anonymously.
- **Tuning** — set repo variables `EVAL_MODEL` / `EVAL_TIMEOUT`; empty values
  fall back to the harness defaults (the `:-` semantics).
- **Output quality** — a manual dispatch with `run_evals=true` additionally runs
  `mise run skills -- evals`.
- **Artifacts** — `**/evals/trigger-results.json` and `**/*-workspace/**`
  (14-day retention).

It is deliberately separate from the PR `CI` workflow: a free model is slow and
near-miss noise is high, so a required PR check would be flaky. To gate PRs on
changed skills later, add a `pull_request` trigger that diffs `.apm/skills/` and
runs `./scripts/test-triggers.sh <skill> 1` for each touched skill.

Expect the first nightly to be red for `rfhub-write-testcase`: the
`__init__.robot` near-miss fires even on the best free model. Treat that as a
signal to sharpen the `description`, not as harness breakage.
