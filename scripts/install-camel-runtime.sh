#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: install-camel-runtime.sh CAMEL_SOURCE ROOTFS" >&2
  exit 2
fi

source_dir=$(realpath "$1")
rootfs=$(realpath "$2")
release=${CAMEL_RELEASE_ID:-}
if [ -z "$release" ]; then
  release=$(git -C "$source_dir" rev-parse --short=12 HEAD 2>/dev/null ||
    sha256sum "$source_dir/systems/harness/live/camel_live.py" |
      cut -c1-12)
fi
case "$release" in
  *[!A-Za-z0-9._-]*|'')
    echo "invalid CAMEL release id: $release" >&2
    exit 2
    ;;
esac
runtime_base=$rootfs/opt/camel-runtime
target=$runtime_base/releases/$release
runtime_target=/opt/camel-runtime/releases/$release

[ -f "$source_dir/systems/harness/live/camel_live.py" ] || {
  echo "canonical CAMEL live harness not found" >&2
  exit 3
}
[ -f "$source_dir/spec/math/README.md" ] || {
  echo "CAMEL math specification not found" >&2
  exit 4
}
[ -f "$source_dir/camel_ctx.py" ] || {
  echo "CAMEL context-recall engine not found" >&2
  exit 6
}
[ -f "$source_dir/benchmark/porter.py" ] || {
  echo "CAMEL recall tokenizer not found" >&2
  exit 7
}
for n in 063 064 068 069 074 075 076 077 078 081 083; do
  find "$source_dir/experiments/engine" -maxdepth 1 -type d \
    -name "$n-*" -print -quit | grep -q . || {
      echo "Sterile Mouth experiment $n not found" >&2
      exit 5
    }
done

rm -rf "$target"
install -d -m 0755 \
  "$target/bin" "$target/benchmark" \
  "$target/systems" "$target/experiments/engine" \
  "$target/knowledge" "$target/spec"
cp -a "$source_dir/camel.py" "$source_dir/camel_ctx.py" "$target/"
cp -a "$source_dir/benchmark/porter.py" "$target/benchmark/"
[ ! -f "$source_dir/AGENTS.md" ] || cp -a "$source_dir/AGENTS.md" "$target/"
cp -a "$source_dir/systems/harness" "$target/systems/"
cp -a "$source_dir/knowledge/math" "$target/knowledge/"
cp -a "$source_dir/spec/math" "$target/spec/"
for path in "$source_dir"/experiments/engine/06[3-9]* \
            "$source_dir"/experiments/engine/07* \
            "$source_dir"/experiments/engine/08*; do
  [ -d "$path" ] && cp -a "$path" "$target/experiments/engine/"
done

live=$target/systems/harness/live/camel_live.py
find "$target/systems/harness" "$target/experiments/engine" \
  -type f -name '*.py' -exec sed -i \
  "s|/home/admin1/camel-sterile-mouth-work|$runtime_target|g" {} +
sed -i \
  -e "s|REPO_ROOT = Path(\"$runtime_target\")|REPO_ROOT = Path(os.environ.get(\"CAMEL_REPO_ROOT\", \"$runtime_target\")).resolve()|" \
  -e 's|if REPO_ROOT.name != "camel-sterile-mouth-work":|if not (REPO_ROOT / "spec/math/README.md").is_file():|' \
  -e "s|if not str(ROOT).startswith(\"$runtime_target/\"):|if not str(ROOT).startswith(str(REPO_ROOT) + os.sep):|" \
  -e "s|OLD_TARGET = Path(\"$runtime_target/experiments/engine/081-pty-tee-tool-observer/camel_pty_tee_tool_observer.py\")|OLD_TARGET = REPO_ROOT / \"experiments/engine/081-pty-tee-tool-observer/camel_pty_tee_tool_observer.py\"|" \
  -e "s|EXPERIMENT_083 = Path(\"$runtime_target/experiments/engine/083-active-memory-routing-enforcement/camel_active_memory_routing.py\")|EXPERIMENT_083 = REPO_ROOT / \"experiments/engine/083-active-memory-routing-enforcement/camel_active_memory_routing.py\"|" \
  -e "s|SUP_075 = Path(\"$runtime_target/experiments/engine/075-camel-noarg-repl-fix/camel_noarg_repl_fix.py\")|SUP_075 = REPO_ROOT / \"experiments/engine/075-camel-noarg-repl-fix/camel_noarg_repl_fix.py\"|" \
  -e "s|SUP_076 = Path(\"$runtime_target/experiments/engine/076-persistent-task-queue-runner/camel_queue_runner.py\")|SUP_076 = REPO_ROOT / \"experiments/engine/076-persistent-task-queue-runner/camel_queue_runner.py\"|" \
  -e "s|SUP_077 = Path(\"$runtime_target/experiments/engine/077-bounded-queue-worker-daemon/camel_queue_worker.py\")|SUP_077 = REPO_ROOT / \"experiments/engine/077-bounded-queue-worker-daemon/camel_queue_worker.py\"|" \
  -e "s|SUP_078 = Path(\"$runtime_target/experiments/engine/078-local-scheduler-worker-tick/camel_scheduler.py\")|SUP_078 = REPO_ROOT / \"experiments/engine/078-local-scheduler-worker-tick/camel_scheduler.py\"|" \
  -e "s|SUP_081 = Path(\"$runtime_target/experiments/engine/081-pty-tee-tool-observer/camel_pty_tee_tool_observer.py\")|SUP_081 = REPO_ROOT / \"experiments/engine/081-pty-tee-tool-observer/camel_pty_tee_tool_observer.py\"|" \
  "$live"
sed -i \
  's|D = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".camel")|D = os.environ.get("CAMEL_CONTEXT_STATE_DIR", os.path.join(os.path.dirname(os.path.abspath(__file__)), ".camel"))|' \
  "$target/camel_ctx.py"

cat >"$target/bin/camel-runtime" <<'RUNTIME'
#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
export CAMEL_REPO_ROOT=${CAMEL_REPO_ROOT:-"$root"}
python=${CAMEL_PYTHON:-/usr/bin/python3}
case "${1:-}" in
  context)
    shift
    exec "$python" "$root/camel_ctx.py" "$@"
    ;;
  *)
    exec "$python" \
      "$root/systems/harness/live/camel_live.py" "$@"
    ;;
esac
RUNTIME
chmod 0755 "$target/bin/camel-runtime"
cat >"$target/camel-runtime.env" <<EOF
CAMEL_HOST_ABI=1
CAMEL_RELEASE_ID=$release
CAMEL_RUNTIME_ENTRY=bin/camel-runtime
CAMEL_CONTEXT_ENTRY=camel_ctx.py
CAMEL_STATE_ABI=1
EOF

install -d -m 0755 "$runtime_base"
ln -sfn "releases/$release" "$runtime_base/current"
rm -rf "$rootfs/opt/camel"
ln -s camel-runtime/current "$rootfs/opt/camel"

install -D -m 0755 \
  "$rootfs/usr/local/libexec/camel-launcher" \
  "$rootfs/usr/local/bin/camel"
install -D -m 0755 \
  "$rootfs/usr/local/libexec/camel-tool-launcher" \
  "$rootfs/usr/local/bin/camel-codex"
ln -sfn camel-codex "$rootfs/usr/local/bin/camel-claude"
ln -sfn camel-codex "$rootfs/usr/local/bin/codex"
ln -sfn camel-claude "$rootfs/usr/local/bin/claude"
install -D -m 0755 \
  "$rootfs/usr/local/libexec/camel-register-tools" \
  "$rootfs/usr/local/bin/camel-register-tools"
chmod 0755 "$live"
install -d -m 0755 \
  "$rootfs/home/camel/.claude/agents" \
  "$rootfs/home/camel/.codex/skills/camel-recall"
install -m 0644 \
  "$rootfs/usr/share/camel/integrations/claude-agent.md" \
  "$rootfs/home/camel/.claude/agents/camel.md"
install -m 0644 \
  "$rootfs/usr/share/camel/integrations/codex-skill.md" \
  "$rootfs/home/camel/.codex/skills/camel-recall/SKILL.md"
if getent passwd camel >/dev/null 2>&1; then
  chown -R camel:camel "$target" "$rootfs/home/camel/.claude" \
    "$rootfs/home/camel/.codex"
fi

python3 -m py_compile "$live"

echo "Installed CAMEL host ABI 1 payload $release in $target"
