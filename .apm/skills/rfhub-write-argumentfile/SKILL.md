---
name: rfhub-write-argumentfile
description: >-
  Use when authoring or editing a Robot Framework argument file (*.args),
  --argumentfile, or ROBOT_EXTRA_ARGS that pass variables/flags into the hub
  runner. Apply when the user says "write an argument file", "args file for
  this suite", or "pass --variable via file". Does not activate for queueing
  suites (rfhub-queue) or replacing catalog suiteIds with an args file. Do not
  edit the runner-generated OUT_DIR/rfhub.args.
license: MIT
compatibility: Designed for Claude Code and Cursor
metadata:
  author: kerpo
  version: "1.0"
---
# rfhub-write-argumentfile

> **Runner image access:** examples referencing the hub runner image point at a
> private registry today (`harbor.kerpo.org/library-private/...`). Use the image
> your hub operator provides; a public runner image is planned. See the package
> README, "Access requirements".

Consumer Robot argument files live in the **suite repo**. The hub runner already writes `OUT_DIR/rfhub.args` per executor (`--suite`, output dir, listener). Do not fight that file.

## When to use

- Adding `*.args` for variables, `--include` of **static** Robot tags, language, or extra flags
- Overlay images / `ROBOT_EXTRA_ARGS=--argumentfile /suite/args/….args`

## Instructions

1. Put files under the suite mount (e.g. `args/ci.args`), UTF-8, one Robot CLI token per line (Robot argument-file syntax).
2. Use them for **variables and options**, not as the hub’s suite selection. Play-from-hub still queues `suiteIds` / `tag` / `all`.
3. Pass into the image with `ROBOT_EXTRA_ARGS`, not by overwriting `OUT_DIR/rfhub.args` (that path is per-executor so parallel `--suite` cannot race on a shared `WORKDIR`).
4. Do not put `--listener` in the args file — the image already attaches `rfhub_listener.py`.
5. Do not use `--include wip` for hub Redis WIP marks (`rfhub_tag_set`); those tags are not in the `.robot` file. See **rfhub-queue**.
6. `--suite` / `--test` in a consumer args file fight orchestrated leaf executors. Leave selection to the hub unless this is a one-shot `docker run` without orch.
7. After writing, if they also need a new leaf or tags, switch to **rfhub-write-suite** / **rfhub-write-testcase**.

Example lines: [references/args-example.md](references/args-example.md).

## Gotchas

- Robot concatenates multiple `--argumentfile`s; the runner’s file is one of them. Duplicate `--outputdir` will break ingest.
- Paths inside the args file must be valid **inside the container** (`/suite/...`), not the host checkout path.
