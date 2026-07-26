#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: package-embedded-recovery-installer.sh VERSION RECOVERY_IMAGE [OUTPUT]" >&2
  exit 2
fi

root_dir=$(cd "$(dirname "$0")/.." && pwd)
version=$1
image=$(realpath "$2")
output=${3:-"$root_dir/out/camel-recovery-$version-installer.zip"}
template=$root_dir/android/recovery-installer/service.sh.in

case "$version" in
  *[!A-Za-z0-9._-]*|'') echo "invalid version label" >&2; exit 3 ;;
esac
[ -s "$image" ] || {
  echo "recovery image not found: $image" >&2
  exit 4
}

image_size=$(stat -c %s "$image")
[ "$image_size" -eq 86888448 ] || {
  echo "recovery image must exactly match the SM-T970 recovery partition" >&2
  exit 5
}
[ $((image_size % 4096)) -eq 0 ] || {
  echo "recovery image size is not 4096-byte aligned" >&2
  exit 6
}
image_blocks=$((image_size / 4096))
image_hash=$(sha256sum "$image" | awk '{print $1}')
module_version=$(printf '%s' "$version" | tr '.-' '__')

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
install -m 0644 "$image" "$work_dir/camel-recovery.img"
install -m 0644 "$root_dir/android/recovery-installer-v3/sepolicy.rule" \
  "$work_dir/sepolicy.rule"
sed \
  -e "s/@VERSION@/$version/g" \
  -e "s/@SHA256@/$image_hash/g" \
  -e "s/@IMAGE_SIZE@/$image_size/g" \
  -e "s/@IMAGE_BLOCKS@/$image_blocks/g" \
  "$template" >"$work_dir/service.sh"
chmod 0755 "$work_dir/service.sh"

{
  printf 'id=camel_recovery_%s_installer\n' "$module_version"
  printf 'name=CAMEL Recovery %s One-Shot Installer\n' "$version"
  printf 'version=%s\n' "$version"
  printf 'versionCode=1\n'
  printf 'author=Tutt Aerospace / Black Flag Data Labs\n'
  printf 'description=Embedded hash-verified recovery backup, write, and readback\n'
} >"$work_dir/module.prop"

mkdir -p "$(dirname "$output")"
output=$(cd "$(dirname "$output")" && pwd)/$(basename "$output")
(
  cd "$work_dir"
  zip -9 -q "$output" module.prop sepolicy.rule service.sh \
    camel-recovery.img
)
(
  cd "$(dirname "$output")"
  sha256sum "$(basename "$output")" >"$(basename "$output").sha256"
)

echo "Built $output"
echo "recovery_sha256=$image_hash"
