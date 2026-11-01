#!/usr/bin/env bash

capture_oom_attribution() {
  echo "=== oom-attribution ${1:-death} $(date -Is 2>/dev/null || date) ==="

  docker inspect -f 'OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} OOMKilledAt={{.State.FinishedAt}}' "$RENDER_CONTAINER" 2>/dev/null \
    || echo "oom-attribution: docker inspect failed (container auto-deleted by --rm, or daemon unreachable)"

  docker exec "$RENDER_CONTAINER" sh -c 'for f in memory.max memory.current memory.events memory.events.local memory.peak; do echo "--- self-cgroup $f ---"; cat "/sys/fs/cgroup/$f" 2>/dev/null || echo "(absent)"; done' 2>/dev/null \
    || echo "oom-attribution: self-cgroup not readable (container already gone)"

  OOM_SIDECAR_HELPER="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/oom-attribution-sidecar.sh"
  if [ -f "$OOM_SIDECAR_HELPER" ]; then bash "$OOM_SIDECAR_HELPER" "$QUARTO_IMAGE"; fi

  return 0
}
