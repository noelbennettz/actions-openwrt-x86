#!/usr/bin/env bash
#
# Boot a built image in QEMU and check that it comes up with LuCI answering.
#
# This is a smoke test, not a test suite: the guest boots from the very disk
# image the release ships, and the evidence is (a) HTTP from the host to the
# guest's LAN address and (b) whatever the serial port produced. It cannot ssh
# into the guest, because the image deliberately has the serial console removed
# (diy-part2.sh) and no password is set on a fresh install.
#
# QEMU user networking is given the guest's own subnet (192.168.1.0/24, the
# default LAN of a fresh OpenWrt) so the host can reach 192.168.1.1 directly
# through slirp; host port 8080 is forwarded to the guest's :80.
#
# Nothing here is required for a release: the caller decides. If QEMU is not
# installed the script warns and exits 0 so a build is never blocked by a
# missing hypervisor.
#
# Usage: scripts/qemu-smoke.sh <firmware-dir> [--timeout SECONDS] [--port PORT]
#                               [--image PATH]
#
set -euo pipefail

case "${1:-}" in
  -h|--help)
    sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

firmware=${1:?usage: qemu-smoke.sh <firmware-dir> [--timeout SECONDS] [--port PORT] [--image PATH]}
shift

timeout_s=${QEMU_TIMEOUT:-600}
host_port=${HOST_PORT:-8080}
image=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout) timeout_s=${2:?--timeout needs a number}; shift 2 ;;
    --port)    host_port=${2:?--port needs a number}; shift 2 ;;
    --image)   image=${2:?--image needs a path}; shift 2 ;;
    *)         echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$firmware" ] || { echo "::error::$firmware is not a directory"; exit 1; }

if ! command -v qemu-system-x86_64 > /dev/null 2>&1; then
  echo "::warning::qemu-system-x86_64 is not installed; skipping the boot smoke test"
  exit 0
fi

workdir=$(mktemp -d)
qemu_pid=''
cleanup() {
  if [ -n "$qemu_pid" ] && kill -0 "$qemu_pid" 2> /dev/null; then
    kill "$qemu_pid" 2> /dev/null || true
    wait "$qemu_pid" 2> /dev/null || true
  fi
  if [ -f "$workdir/serial.log" ]; then
    echo "=== serial output (tail) ==="
    tail -n 40 "$workdir/serial.log" || true
    # Keep the full log with the downloaded firmware, so a caller (CI) can
    # upload it as evidence even when the boot failed.
    cp "$workdir/serial.log" "$firmware/qemu-serial.log" 2> /dev/null || true
  fi
  if [ "${KEEP_QEMU_WORKDIR:-0}" = '1' ]; then
    echo "working directory kept: $workdir"
  else
    rm -rf "$workdir"
  fi
}
trap cleanup EXIT

# Pick the legacy-BIOS squashfs image: SeaBIOS is part of qemu, whereas an EFI
# boot would need OVMF in the runner image. ext4 is the fallback.
if [ -z "$image" ]; then
  for candidate in \
    "$firmware"/openwrt-*-generic-squashfs-combined.img.gz \
    "$firmware"/openwrt-*-generic-squashfs-combined.img \
    "$firmware"/openwrt-*-generic-ext4-combined.img.gz \
    "$firmware"/openwrt-*-generic-ext4-combined.img; do
    if [ -f "$candidate" ]; then
      image=$candidate
      break
    fi
  done
fi
if [ -z "$image" ] || [ ! -f "$image" ]; then
  echo "::error::no combined BIOS image found in $firmware (looked for squashfs-combined and ext4-combined)"
  exit 1
fi

echo "booting $(basename "$image")"
case "$image" in
  *.gz)
    gunzip -c "$image" > "$workdir/disk.img"
    ;;
  *)
    cp "$image" "$workdir/disk.img"
    ;;
esac

# -daemonize so the script can poll the guest; the pid file makes the cleanup
# reliable even if qemu exits on its own.
qemu-system-x86_64 \
  -machine q35 -m 512M -smp 2 \
  -display none -monitor none -no-reboot -daemonize \
  -pidfile "$workdir/qemu.pid" \
  -drive file="$workdir/disk.img",format=raw,if=ide \
  -netdev "user,id=n0,net=192.168.1.0/24,host=192.168.1.2,hostfwd=tcp:127.0.0.1:${host_port}-192.168.1.1:80" \
  -device e1000,netdev=n0 \
  -serial "file:$workdir/serial.log"

qemu_pid=$(cat "$workdir/qemu.pid")
echo "qemu pid $qemu_pid, waiting up to ${timeout_s}s for http://127.0.0.1:${host_port}/"

deadline=$(( $(date +%s) + timeout_s ))
code=''
while [ "$(date +%s)" -lt "$deadline" ]; do
  code=$(curl -s -o "$workdir/index.html" -w '%{http_code}' --max-time 5 \
    "http://127.0.0.1:${host_port}/" || true)
  case "$code" in
    200|302|303|307|308) break ;;
  esac
  if [ -n "$qemu_pid" ] && ! kill -0 "$qemu_pid" 2> /dev/null; then
    echo "::error::qemu exited before the guest answered"
    exit 1
  fi
  sleep 5
done

case "$code" in
  200|302|303|307|308)
    echo "guest answered with HTTP $code on port $host_port"
    ;;
  *)
    echo "::error::the guest did not answer on port $host_port within ${timeout_s}s (last HTTP code: '${code:-none}')"
    exit 1
    ;;
esac

# A redirect from / to /cgi-bin/luci is LuCI; ask the page itself as well, so a
# bare httpd would not pass.
if curl -s --max-time 10 "http://127.0.0.1:${host_port}/cgi-bin/luci/" |
     grep -qi 'luci'; then
  echo "LuCI is being served by the guest"
else
  echo "::error::the guest answers but /cgi-bin/luci does not look like LuCI"
  exit 1
fi

echo "boot smoke test passed"
