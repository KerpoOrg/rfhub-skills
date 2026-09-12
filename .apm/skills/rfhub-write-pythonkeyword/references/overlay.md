# Runner overlay

```dockerfile
FROM harbor.kerpo.org/library-private/rf-hub-runner:pabot
# pip install your lib extras; Browser + Chromium if needed
```

Pass `PYTHONPATH` and `ROBOT_EXTRA_ARGS` instead of copying `entrypoint.sh`.

Published bases: `harbor.kerpo.org/library-private/rf-hub-runner:latest` and `:pabot`. Pin `:sha-<gitsha>` in CI.
