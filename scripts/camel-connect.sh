#!/usr/bin/env bash
set -euo pipefail

host=${CAMEL_HOST:-172.31.0.1}
key=${CAMEL_SSH_KEY:-"$HOME/.ssh/camel-phone-recovery-ed25519"}

[ -s "$key" ] || {
  echo "Phone recovery key is missing: $key" >&2
  exit 2
}

if ! ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
  interface=
  for path in /sys/class/net/*; do
    candidate=${path##*/}
    case "$candidate" in
      lo|wlan*|rmnet*|dummy*|tun*) continue ;;
    esac
    [ -e "$path/device" ] || continue
    interface=$candidate
    break
  done

  if [ -n "$interface" ] && command -v su >/dev/null 2>&1; then
    echo "Assigning phone recovery address to $interface"
    if ! su -c \
      "ip link set '$interface' up; ip addr replace 172.31.0.2/24 dev '$interface'"; then
      echo "Phone root was unavailable; trying the existing USB address" >&2
    fi
  fi
fi

ping -c 1 -W 3 "$host" >/dev/null 2>&1 || {
  echo "CAMEL USB network is not reachable at $host" >&2
  echo "Detected interfaces:" >&2
  ip -brief link >&2 || true
  exit 3
}

exec ssh -i "$key" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=5 \
  "camel@$host" "$@"
