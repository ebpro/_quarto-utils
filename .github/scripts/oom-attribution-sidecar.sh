#!/usr/bin/env bash
set -u

QUARTO_IMAGE="${1:-}"
if [ -z "$QUARTO_IMAGE" ]; then
  echo "oom-attribution: sidecar helper missing image argument" >&2
  exit 1
fi

docker run --rm --cgroupns=host -v /sys/fs/cgroup:/hostcg:ro "$QUARTO_IMAGE" sh -c 'p=$(sed -n "s|^0::|/|p" /proc/1/cgroup 2>/dev/null); if [ -n "$p" ]; then d=$(dirname "$p"); for f in memory.max memory.current memory.events memory.events.local memory.peak; do echo "--- sidecar-cgroup $d $f ---"; cat "/hostcg$d/$f" 2>/dev/null || echo "(absent)"; done; else m=$(sed -n "s|^[0-9]*:memory:|/|p" /proc/1/cgroup 2>/dev/null); if [ -n "$m" ]; then d=$(dirname "$m"); for f in memory.limit_in_bytes memory.usage_in_bytes memory.failcnt memory.oom_control; do echo "--- sidecar-cgroup-v1 $d $f ---"; cat "/hostcg/memory$d/$f" 2>/dev/null || echo "(absent)"; done; else echo "oom-attribution: no cgroup path in /proc/1/cgroup"; fi; fi' 2>/dev/null || echo "oom-attribution: sidecar-cgroup helper failed (cgroupns flag/daemon/mount unsupported)"
