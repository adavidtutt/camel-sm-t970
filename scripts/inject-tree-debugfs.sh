#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: inject-tree-debugfs.sh TREE EXT4_IMAGE" >&2
  exit 2
fi

tree=$(realpath "$1")
image=$(realpath "$2")
[ -d "$tree" ]
[ -f "$image" ]

commands=$(mktemp)
cleanup() {
  rm -f "$commands"
}
trap cleanup EXIT

quote() {
  case "$1" in
    *\"*|*$'\n'*)
      echo "unsupported path for debugfs injection: $1" >&2
      exit 3
      ;;
  esac
  printf '"%s"' "$1"
}

set_owner() {
  relative=$1
  destination=$2
  case "$relative" in
    opt/camel|opt/camel/*)
      printf 'set_inode_field %s uid 1000\n' \
        "$(quote "$destination")" >>"$commands"
      printf 'set_inode_field %s gid 1000\n' \
        "$(quote "$destination")" >>"$commands"
      ;;
  esac
}

while IFS= read -r -d '' path; do
  relative=${path#"$tree"/}
  destination=/$relative
  printf 'mkdir %s\n' "$(quote "$destination")" >>"$commands"
  set_owner "$relative" "$destination"
done < <(find "$tree" -mindepth 1 -type d -print0 | sort -z)

while IFS= read -r -d '' path; do
  relative=${path#"$tree"/}
  destination=/$relative
  printf 'rm %s\n' "$(quote "$destination")" >>"$commands"
  printf 'write %s %s\n' "$(quote "$path")" "$(quote "$destination")" \
    >>"$commands"
  mode=$(stat -c %a "$path")
  printf 'set_inode_field %s mode 0100%s\n' \
    "$(quote "$destination")" "$mode" >>"$commands"
  set_owner "$relative" "$destination"
done < <(find "$tree" -mindepth 1 -type f -print0 | sort -z)

while IFS= read -r -d '' path; do
  relative=${path#"$tree"/}
  destination=/$relative
  target=$(readlink "$path")
  printf 'rm %s\n' "$(quote "$destination")" >>"$commands"
  printf 'symlink %s %s\n' \
    "$(quote "$destination")" "$(quote "$target")" >>"$commands"
  set_owner "$relative" "$destination"
done < <(find "$tree" -mindepth 1 -type l -print0 | sort -z)

debugfs -w -f "$commands" "$image"
