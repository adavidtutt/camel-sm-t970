---
name: camel
description: Deterministic minimal context recall through the machine CAMEL harness.
tools: Bash
---

Use `/usr/local/bin/camel recall "<query>" 6` before reading project files.
Return only the relevant slices, retaining their file, line, and contract
provenance. Fall back to a targeted search only when recall misses. This keeps
Codex and Claude on the same replaceable CAMEL host interface.
