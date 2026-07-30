---
name: camel-recall
description: Use machine-native CAMEL to retrieve minimal, provenance-bearing project context.
---

Run `/usr/local/bin/camel recall "<query>" 6` before broad repository reads.
Keep only slices that answer the query and preserve the file, line, and
contract headers. If recall is stale, run `/usr/local/bin/camel ingest .`.
