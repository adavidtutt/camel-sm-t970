#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: install-camel-runtime.sh CAMEL_SOURCE ROOTFS" >&2
  exit 2
fi

source_dir=$(realpath "$1")
rootfs=$(realpath "$2")
target=$rootfs/opt/camel

[ -f "$source_dir/systems/harness/live/camel_live.py" ] || {
  echo "canonical CAMEL live harness not found" >&2
  exit 3
}
[ -f "$source_dir/spec/math/README.md" ] || {
  echo "CAMEL math specification not found" >&2
  exit 4
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
  "$target/systems" "$target/experiments/engine" \
  "$target/knowledge" "$target/spec"
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
  's|/home/admin1/camel-sterile-mouth-work|/opt/camel|g' {} +
sed -i \
  -e 's|REPO_ROOT = Path("/opt/camel")|REPO_ROOT = Path(os.environ.get("CAMEL_REPO_ROOT", "/opt/camel")).resolve()|' \
  -e 's|if REPO_ROOT.name != "camel-sterile-mouth-work":|if not (REPO_ROOT / "spec/math/README.md").is_file():|' \
  -e 's|if not str(ROOT).startswith("/opt/camel/"):|if not str(ROOT).startswith(str(REPO_ROOT) + os.sep):|' \
  "$live"

install -D -m 0755 \
  "$rootfs/usr/local/libexec/camel-launcher" \
  "$rootfs/usr/local/bin/camel"
install -D -m 0755 \
  "$rootfs/usr/local/libexec/camel-tool-launcher" \
  "$rootfs/usr/local/bin/camel-codex"
ln -sfn camel-codex "$rootfs/usr/local/bin/camel-claude"
install -D -m 0755 \
  "$rootfs/usr/local/libexec/camel-register-tools" \
  "$rootfs/usr/local/bin/camel-register-tools"
chmod 0755 "$live"
if getent passwd camel >/dev/null 2>&1; then
  chown -R camel:camel "$target"
fi

python3 -m py_compile "$live"

echo "Installed native CAMEL runtime in $target"
