# Metrics and attachments

Typical path:

1. `rfhub_metrics_overview` — pass-rate trend, volume, top failures, embedded watchlist
2. `rfhub_metrics_watchlist` — consecutive fail, duration regression, mixed pass/fail
3. `rfhub_metrics_test` — `series`, `flips`, `consecutiveFails`, `flaky`, `repeatingErrors`, `durationStats`
4. `rfhub_run_log` — failure excerpt for one `runId`

`durationStats` (default last 30 days): `whenPassing` / `whenFailing` with `count`, `minS`, `medianS`, `p75S`, `maxS`.

Attachments: digest `attachments: [{ path, url, contentType }]`. List/download `GET /api/runs/{runId}/attachments` (anonymous UI). Same `relPath` under multiple parts uses `?part=`.
