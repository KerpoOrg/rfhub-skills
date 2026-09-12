---
description: Failure messages must name uploaded attachments so hub agent digests can link them
applyTo: "**/*.{robot,resource}"
---

- Canonical result is `output.xml`. Do not tell agents to scrape `log.html` / `report.html` as the primary viewer.
- When a test fails with a screenshot, trace, or other sidecar, put the path **relative to `OUT_DIR`** in the FAIL message so the hub can match it to the upload manifest.
- Preferred forms: `attachment #1: test-results/foo/test-failed-1.png` or `browser/screenshot-….png`. Absolute paths that end with that relative suffix are ok (`/out/test-results/…/a.png`).
- Do not rely on executor host paths the hub cannot open. Only uploaded bytes are stored.
- Allowlisted upload extensions include `png jpg jpeg webp gif webm mp4 txt json zip pdf har html` (not `output.xml` / `report.html` / `log.html` as attachments).
- After ingest, agents use `attachments[]` on `rfhub_run` / `rfhub_run_log`. If files uploaded but no message matched, digests include `attachmentHint`.
