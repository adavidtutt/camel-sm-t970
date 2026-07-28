#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
source_dir=${CAMEL_SOURCE_DIR:?set CAMEL_SOURCE_DIR to the canonical CAMEL checkout}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

install -d "$test_root/usr/local/libexec" "$test_root/usr/local/bin" \
  "$test_root/home/camel"
cp "$root_dir"/rootfs-overlay/usr/local/libexec/camel-* \
  "$test_root/usr/local/libexec/"

"$root_dir/scripts/install-camel-runtime.sh" "$source_dir" "$test_root"
test -x "$test_root/usr/local/bin/camel"
test -x "$test_root/usr/local/bin/camel-codex"
test -L "$test_root/usr/local/bin/camel-claude"
test -f "$test_root/opt/camel/spec/math/README.md"
test -f "$test_root/opt/camel/systems/harness/live/camel_live.py"
find "$test_root/opt/camel/systems/harness" \
     "$test_root/opt/camel/experiments/engine" \
  -type f -name '*.py' -exec sed -i \
  "s#/opt/camel#$test_root/opt/camel#g" {} +
CAMEL_REPO_ROOT="$test_root/opt/camel" HOME="$test_root/home/camel" \
  python3 "$test_root/opt/camel/systems/harness/live/camel_live.py" /status \
  | grep -q '^status=pass$'
printf '#!/bin/sh\nprintf "codex:%%s\\n" "$*"\n' \
  >"$test_root/codex-real"
printf '#!/bin/sh\nprintf "claude:%%s\\n" "$*"\n' \
  >"$test_root/claude-real"
chmod 0755 "$test_root/codex-real" "$test_root/claude-real"
CAMEL_REPO_ROOT="$test_root/opt/camel" HOME="$test_root/home/camel" \
CAMEL_REAL_CODEX_PATH="$test_root/codex-real" \
  python3 "$test_root/opt/camel/systems/harness/live/camel_live.py" \
  tool codex --version | grep -q '^codex:--version$'
CAMEL_REPO_ROOT="$test_root/opt/camel" HOME="$test_root/home/camel" \
CAMEL_REAL_CLAUDE_PATH="$test_root/claude-real" \
  python3 "$test_root/opt/camel/systems/harness/live/camel_live.py" \
  tool claude --version | grep -q '^claude:--version$'

echo "PASS: native CAMEL runtime stages and starts"
