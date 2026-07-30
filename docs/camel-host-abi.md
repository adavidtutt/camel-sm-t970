# CAMEL machine host ABI

CAMEL changes faster than the tablet operating system. The operating system
therefore owns a small, stable host and treats CAMEL itself as a replaceable
payload.

## Stable machine layer

The host is `/usr/local/libexec/camel-host`. `/usr/local/bin/camel`, `codex`,
and `claude` enter through it. The host owns:

- discovery and atomic selection of the active CAMEL release;
- stable state paths below `~/.camel`;
- real Codex and Claude binary paths and recursion prevention;
- transparent TTY-preserving tool passthrough;
- deterministic context-recall commands used by both CLI integrations;
- compatibility checks, health probes, rollback, and safe direct passthrough
  when no compatible CAMEL payload exists.

`camel-harness.service` validates this layer once during boot and consumes no
resident memory afterward.

## Payload ABI 1

Payloads live at:

```text
/opt/camel-runtime/releases/RELEASE/
  camel-runtime.env
  bin/camel-runtime
```

The manifest must contain:

```text
CAMEL_HOST_ABI=1
CAMEL_RELEASE_ID=RELEASE
CAMEL_RUNTIME_ENTRY=bin/camel-runtime
CAMEL_CONTEXT_ENTRY=camel_ctx.py
CAMEL_STATE_ABI=1
```

The executable receives the existing CAMEL command surface. It must support:

- `/status`, returning `status=pass`;
- `tool codex ...` and `tool claude ...`, preserving standard streams, TTY
  behavior, arguments, and exit status;
- `context recall|ingest|learn|report|seed|seed_codex|add|consolidate|related`;
- the evolving CAMEL commands such as `do`, `task`, `worker`, `scheduler`,
  `memory`, and `route`.

The host exports `CAMEL_REPO_ROOT`, `CAMEL_HOME`,
`CAMEL_CONTEXT_STATE_DIR`, `CAMEL_REAL_CODEX_PATH`, and
`CAMEL_REAL_CLAUDE_PATH`. Payload code must use these instead of fixed
installation paths.

## Token-reduction interface

Both Claude and Codex receive an integration instruction that calls:

```sh
camel recall "narrow question" 6
```

This preserves the Sterile Mouth progression:

1. transparent CLI passthrough;
2. PTY observation without breaking interactivity;
3. redacted session distillation into persistent memory;
4. memory-aware routing and policy;
5. minimal, provenance-bearing recall instead of broad file reads.

The recall store is outside the release directory, so changing CAMEL does not
discard learned routes or memoized context.

## Atomic replacement

Install a new payload into a new release directory, then run:

```sh
sudo camel-runtime-switch RELEASE
```

The switch validates ABI 1 and runs the payload status probe before atomically
changing `/opt/camel-runtime/current`. The previous link is retained. Roll
back without rebuilding the root filesystem:

```sh
sudo camel-runtime-switch --rollback
```

Only `bin/camel-runtime` and `camel-runtime.env` must be adapted when a future
CAMEL implementation changes its internal layout.
