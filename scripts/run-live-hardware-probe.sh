#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)

"$root_dir/scripts/camel-connect.sh" sudo /bin/sh -s \
  <"$root_dir/scripts/live-hardware-probe.sh"
