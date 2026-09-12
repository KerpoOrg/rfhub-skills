# Argument file example

```text
# args/ci.args — variables only; do not add --listener or --outputdir
--variable
ENV:staging
--pythonpath
/suite/libs
```

One-shot runner (no orchestrator):

```bash
docker run --rm \
  -e ROBOT_EXTRA_ARGS='--argumentfile /suite/args/ci.args' \
  -v "$PWD:/suite:ro" \
  harbor.kerpo.org/library-private/rf-hub-runner:latest
```

Orchestrated batches: set the same `ROBOT_EXTRA_ARGS` on the executor environment if every leaf should see the file. Still queue leaves with `rfhub_queue`.
