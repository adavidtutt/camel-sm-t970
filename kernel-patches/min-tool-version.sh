#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Compatibility helper from upstream Linux v5.15. The pinned Samsung tree
# calls this helper from as-version.sh but omits the file.

set -e

if [ $# != 1 ]; then
  echo "Usage: $0 toolname" >&2
  exit 1
fi

case "$1" in
  binutils)
    echo 2.23.0
    ;;
  gcc)
    echo 5.1.0
    ;;
  icc)
    echo 16.0.3
    ;;
  llvm)
    if [ "$SRCARCH" = s390 ]; then
      echo 13.0.0
    else
      echo 10.0.1
    fi
    ;;
  *)
    echo "$1: unknown tool" >&2
    exit 1
    ;;
esac
