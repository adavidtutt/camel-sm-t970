#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir=${CAMEL_SOURCE_DIR:?set CAMEL_SOURCE_DIR to the canonical CAMEL checkout}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

install -d "$test_root/home/camel"
cp -a "$root_dir/rootfs-overlay/." "$test_root/"

"$root_dir/scripts/install-camel-runtime.sh" "$source_dir" "$test_root"
test -x "$test_root/usr/local/bin/camel"
test -x "$test_root/usr/local/bin/camel-codex"
test -L "$test_root/usr/local/bin/camel-claude"
test -L "$test_root/opt/camel"
payload=$(readlink -f "$test_root/opt/camel-runtime/current")
initial_release=$(sed -n 's/^CAMEL_RELEASE_ID=//p' \
  "$payload/camel-runtime.env")
test -f "$payload/camel-runtime.env"
test -x "$payload/bin/camel-runtime"
test -f "$payload/spec/math/README.md"
test -f "$payload/camel_ctx.py"
test -f "$payload/systems/harness/live/camel_live.py"
find "$payload/systems/harness" \
     "$payload/experiments/engine" \
  -type f -name '*.py' -exec sed -i \
  "s#/opt/camel-runtime/releases/$initial_release#$payload#g" {} +
CAMEL_REPO_ROOT="$payload" HOME="$test_root/home/camel" \
  python3 "$payload/systems/harness/live/camel_live.py" /status \
  | grep '^status=pass$' >/dev/null
printf '#!/bin/sh\nprintf "codex:%%s\\n" "$*"\n' \
  >"$test_root/codex-real"
printf '#!/bin/sh\nprintf "claude:%%s\\n" "$*"\n' \
  >"$test_root/claude-real"
chmod 0755 "$test_root/codex-real" "$test_root/claude-real"
host="$test_root/usr/local/libexec/camel-host"
common="CAMEL_RUNTIME_BASE=$test_root/opt/camel-runtime"
env $common CAMEL_PYTHON="$(command -v python3)" \
  HOME="$test_root/home/camel" \
  CAMEL_REAL_CODEX_PATH="$test_root/codex-real" \
  "$host" tool codex --version | grep '^codex:--version$' >/dev/null
env $common CAMEL_PYTHON="$(command -v python3)" \
  HOME="$test_root/home/camel" \
  CAMEL_REAL_CLAUDE_PATH="$test_root/claude-real" \
  "$host" tool claude --version | grep '^claude:--version$' >/dev/null
env $common CAMEL_PYTHON="$(command -v python3)" \
  HOME="$test_root/home/camel" "$host" doctor |
  grep '^status=pass$' >/dev/null

mkdir -p "$test_root/context-fixture"
printf 'CAMEL host interface keeps payloads replaceable.\\n' \
  >"$test_root/context-fixture/README.md"
env $common CAMEL_PYTHON="$(command -v python3)" \
  HOME="$test_root/home/camel" "$host" ingest \
  "$test_root/context-fixture" >/dev/null
env $common CAMEL_PYTHON="$(command -v python3)" \
  HOME="$test_root/home/camel" "$host" recall \
  "replaceable payload interface" 1 |
  grep 'CAMEL host interface' >/dev/null

CAMEL_RELEASE_ID=next-camel \
  "$root_dir/scripts/install-camel-runtime.sh" "$source_dir" "$test_root" \
  >/dev/null
next_payload=$test_root/opt/camel-runtime/releases/next-camel
find "$next_payload/systems/harness" \
     "$next_payload/experiments/engine" \
  -type f -name '*.py' -exec sed -i \
  "s#/opt/camel-runtime/releases/next-camel#$next_payload#g" {} +
ln -sfn "releases/$initial_release" "$test_root/opt/camel-runtime/current"
CAMEL_RUNTIME_BASE="$test_root/opt/camel-runtime" \
CAMEL_PYTHON="$(command -v python3)" \
  "$test_root/usr/local/sbin/camel-runtime-switch" next-camel |
  grep 'CAMEL_ACTIVE_RELEASE=next-camel' >/dev/null
test "$(readlink "$test_root/opt/camel-runtime/current")" = \
  releases/next-camel
CAMEL_RUNTIME_BASE="$test_root/opt/camel-runtime" \
CAMEL_PYTHON="$(command -v python3)" \
  "$test_root/usr/local/sbin/camel-runtime-switch" --rollback >/dev/null
test "$(readlink "$test_root/opt/camel-runtime/current")" = \
  "releases/$initial_release"

echo "PASS: machine CAMEL host stages, recalls, and preserves tool passthrough"
