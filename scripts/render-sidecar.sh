#!/usr/bin/env bash
#
# render-sidecar.sh — OOM self-attribution + hang-watchdog units for the
# "Render with Quarto (Docker)" step of .github/workflows/render-quarto.yml.
#
# WHY THIS FILE EXISTS (post-v1.3.44 — the GitHub 21000-char expression cap)
#   A `run:` block that embeds ${{ ... }} expressions is measured by the
#   Actions service as ONE expression against its 21000-char cap. The
#   v1.3.37 watchdog growth + the v1.3.38 OOM-attribution growth pushed the
#   render run-block to ~39.6K chars with three ${{ inputs.* }} tokens
#   inside, and every consumer run of tags v1.3.41…v1.3.44 died at workflow
#   preparation (0 jobs) with:
#     (Line 454, Col 14): Exceeded max expression length 21000
#   The fix is a size refactor, not a feature removal, in two parts:
#     1. every ${{ ... }} token was hoisted out of every run-block into the
#        owning step's env: mapping — the render run-block is now
#        expression-free, so the cap no longer applies to it at all;
#     2. this file carries the two large sentinel-delimited units so the
#        block keeps real margin even if a future edit re-introduces an
#        expression. The units are a PURE MOVE: byte-identical between the
#        sentinels, except the three input assignments at the top of the
#        watchdog unit, which now read the step env vars HANG_MINUTES /
#        HANG_ACTION / HANG_EXT_MAX (hoisted from inputs.hang-detection-
#        minutes / inputs.hang-action / inputs.hang-max-extensions).
#
# HOW IT IS LOADED
#   The render step sources it from the utils checkout:
#     . "$GITHUB_WORKSPACE/_quarto-utils/scripts/render-sidecar.sh"
#   The "Checkout utilities repo" step already pinned that checkout to
#   inputs.utils-ref, so the sourced units are exactly the caller's
#   requested ref — no second network fetch (the render already depends on
#   this checkout for the shared quarto config). The source is FAIL-CLOSED:
#   a missing file aborts the render step with a clear ::error:: + exit 1 —
#   never a silent skip, which would regress the watchdog liveness
#   corroboration, the OOM self-attribution and the hang forensics.
#
# ENVIRONMENT CONTRACT (provided by the render step before the source)
#   HANG_MINUTES     inputs.hang-detection-minutes (0 = watchdog off)
#   HANG_ACTION      inputs.hang-action ('kill' | 'report-only')
#   HANG_EXT_MAX     inputs.hang-max-extensions (liveness-extension bound)
#   RENDER_CONTAINER, RENDER_LOG, QUARTO_IMAGE — set by the step/script
#   GITHUB_WORKSPACE, GITHUB_STEP_SUMMARY      — runner defaults
#
# Sourced, not executed: the caller's shell options apply (the render step
# runs under the Actions default `bash -e`). This file defines
# capture_oom_attribution and the wd_* helpers, validates the hoisted
# inputs, and arms the watchdog subshell (WATCHDOG_PID) when HANG_MINUTES
# is non-zero.
#
# SENTINELS ARE LOAD-BEARING: scripts/test-hang-watchdog.sh extracts both
# units verbatim from THIS file. Do not reflow the sentinel comments.

# >>> OOM-CAPTURE-BEGIN — extracted verbatim by scripts/test-hang-watchdog.sh
#     (case i: every arm must be non-fatal); do not reflow the sentinels.
# v1.3.38: OOM self-attribution, emitted to the RETAINED JOB LOG (the
# quota-immune transport be6ee49 established). Called on the two death
# paths: the watchdog forensics block (container still alive -> the
# exec arm adds the container's own cgroup view) and the PIPESTATUS
# failure branch (normal death -> runs BEFORE the EXIT trap's rm arm,
# so docker inspect may still win the --rm auto-delete race).
# The decisive fields are the SIDECAR cgroup's memory.events pair:
#   memory.events        aggregates the whole subtree — a docker-
#                          enforced OOM of the render child lands here
#                          (max/oom/oom_kill) while the sidecar's own
#                          cap stayed untouched;
#   memory.events.local  fires only when the SIDECAR's own cgroup cap
#                          is hit.
# Non-zero local counters alongside OOMKilled=false = the old
# unattributable shape, now positively attributed to the cluster-side
# ceiling instead of the render. ARC runner pods are ephemeral (one
# job per pod), so the counters are per-run by construction.
# The helper container trick is required because the step's own shell
# lives in the RUNNER container's cgroup, a sibling of the sidecar's:
# a container started BY the sidecar's dockerd is a cgroup child of
# dockerd, hence its parent cgroup IS the sidecar container's cgroup.
# --cgroupns=host + a read-only /sys/fs/cgroup bind (resolved in the
# daemon's mount namespace) exposes it. The cgroup-v1 fallback reads
# the equivalent files. No --oom-score-adj: the cap is cgroup-wide, a
# per-process adj does not change which ceiling fires.
capture_oom_attribution() {
  echo "=== oom-attribution ${1:-death} $(date -Is 2>/dev/null || date) ==="
  docker inspect -f 'OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}} OOMKilledAt={{.State.FinishedAt}}' "$RENDER_CONTAINER" 2>/dev/null \
    || echo "oom-attribution: docker inspect failed (container auto-deleted by --rm, or daemon unreachable)"
  docker exec "$RENDER_CONTAINER" sh -c 'for f in memory.max memory.current memory.events memory.events.local memory.peak; do echo "--- self-cgroup $f ---"; cat "/sys/fs/cgroup/$f" 2>/dev/null || echo "(absent)"; done' 2>/dev/null \
    || echo "oom-attribution: self-cgroup not readable (container already gone)"
  # Single-line sh -c on purpose: shellcheck only parses the literal as an
  # inner script when sh -c is the direct command (a `timeout 90` prefix or a
  # multi-line literal both degrade it to plain-string analysis -> SC2016 on
  # every $var). No timeout wrapper: same un-guarded-daemon posture as the
  # inspect/exec arms and be6ee49's forensics; step/job timeouts backstop.
  docker run --rm --cgroupns=host -v /sys/fs/cgroup:/hostcg:ro "$QUARTO_IMAGE" sh -c 'p=$(sed -n "s|^0::|/|p" /proc/1/cgroup 2>/dev/null); if [ -n "$p" ]; then d=$(dirname "$p"); for f in memory.max memory.current memory.events memory.events.local memory.peak; do echo "--- sidecar-cgroup $d $f ---"; cat "/hostcg$d/$f" 2>/dev/null || echo "(absent)"; done; else m=$(sed -n "s|^[0-9]*:memory:|/|p" /proc/1/cgroup 2>/dev/null); if [ -n "$m" ]; then d=$(dirname "$m"); for f in memory.limit_in_bytes memory.usage_in_bytes memory.failcnt memory.oom_control; do echo "--- sidecar-cgroup-v1 $d $f ---"; cat "/hostcg/memory$d/$f" 2>/dev/null || echo "(absent)"; done; else echo "oom-attribution: no cgroup path in /proc/1/cgroup"; fi; fi' 2>/dev/null || echo "oom-attribution: sidecar-cgroup helper failed (cgroupns flag/daemon/mount unsupported)"
  return 0
}
# <<< OOM-CAPTURE-END

# --- v1.3.31-candidate: hang watchdog (input hang-detection-minutes, 0=off) ---
# Inactivity cap on the render stream: liveness = max mtime of RENDER_LOG and
# quarto-exec.log; on sustained silence the sidecar dumps forensics, emits a
# ::error::HANG-DETECTED annotation and docker-kills the render container so
# `docker run` exits non-zero. The PIPESTATUS branch below stays the SOLE
# step-status decider (subshell runs `set +e`, every probe `|| true`; the
# guarded if keeps the main `bash -e` shell inert when the feature is off).
#
# v1.3.37 — INACTIVITY IS A TRIGGER, NOT A VERDICT. The pre-v1.3.37 sidecar
# killed on the mtime deadline alone and only inspected kernel state AFTER the
# decision, so a legitimately-busy-but-silent cell (a live python3 kernel
# compiling/loading, no stream output) was indistinguishable from a wedged one.
# DEV-EXP run 39201344899 / job 117894776666 is exactly that shape: the trip
# was correct-by-rule at [17/32] with a kernel started 2.5 s earlier, and the
# evidence needed to attribute it was destroyed by the artifact-quota error.
# Before ANY kill the sidecar now corroborates liveness with two `docker top`
# samples WATCHDOG_PROBE_SECS apart, reading per-PID CPU from
# $PROC_ROOT/<pid>/stat (utime+stime clock ticks) and falling back to the ps
# TIME column when /proc is unreadable. Verdicts:
#   kernel child present AND accumulating CPU -> NO kill:
#     ::warning::LIVE-KERNEL-CORROBORATED (names the live PID, the CPU delta
#     and the elapsed silence) + a bounded re-arm. See hang-max-extensions:
#     the bound is what keeps a 20-min cap from becoming an unbounded hang.
#   no kernel child, OR zero CPU delta across both samples -> the v1.3.36
#     path VERBATIM: ::error::HANG-DETECTED -> forensics -> docker kill ->
#     exit 137. Message shape and exit code are an encoded contract.
#   process table vanished during the probe and the container is no longer
#     running -> ::notice::HANG-WATCHDOG-STOOD-DOWN, no kill, no false error.
# Every new outcome uses a NEW marker; HANG-DETECTED is never modified.
# hang-detection-minutes=0 still disables the whole block: the guard below
# is byte-identical, so the 35 wrappers that never set it are unaffected.
# >>> WATCHDOG-BEGIN — extracted verbatim by scripts/test-hang-watchdog.sh;
#     do not reflow the sentinels or change the block's variable surface.
# post-v1.3.44 (expression-cap fix): the three inputs.* expression tokens
# were hoisted to the render step's env: mapping — this unit now reads the
# step env vars instead of embedding GitHub expressions (a run-block
# containing them is measured as one expression against the 21000-char cap).
HANG_MIN="${HANG_MINUTES}"
HANG_MODE="${HANG_ACTION}"
# HANG_EXT_MAX is consumed directly from the step env (the hoisted input
# variable keeps its name); the case validation below reads/mutates it.
case "$HANG_MODE" in
  kill|report-only) ;;
  *)
    echo "::warning::HANG-WATCHDOG-CONFIG: unknown hang-action '$HANG_MODE' — falling back to 'kill' (the v1.3.36 contract)"
    HANG_MODE="kill"
    ;;
esac
case "$HANG_EXT_MAX" in
  ''|*[!0-9]*)
    echo "::warning::HANG-WATCHDOG-CONFIG: hang-max-extensions '$HANG_EXT_MAX' is not a non-negative integer — using 3"
    HANG_EXT_MAX=3
    ;;
esac
# Tunables. `: "${V:=d}"` (not a plain assignment) is deliberate: it is the
# seam scripts/test-hang-watchdog.sh uses to fast-forward the sidecar, and it
# costs nothing on the runner. Values in seconds.
: "${WATCHDOG_POLL_SECS:=30}"
: "${WATCHDOG_PROBE_SECS:=60}"
: "${WATCHDOG_EXTEND_SECS:=300}"
: "${PROC_ROOT:=/proc}"
WATCHDOG_PID=""
if [ -n "$HANG_MIN" ] && [ "$HANG_MIN" != "0" ]; then
  echo ">> Hang watchdog armed: ${HANG_MIN}-min inactivity cap (container: $RENDER_CONTAINER)"
  echo ">> Liveness corroboration ON: probe ${WATCHDOG_PROBE_SECS}s x2, extend ${WATCHDOG_EXTEND_SECS}s, max ${HANG_EXT_MAX} extensions (worst-case cap $(( HANG_MIN + (HANG_EXT_MAX * WATCHDOG_EXTEND_SECS / 60) )) min), action=${HANG_MODE}"
  (
    set +e
    LIMIT=$(( HANG_MIN * 60 ))
    FORENSICS_DIR="$GITHUB_WORKSPACE/hang-forensics"
    mkdir -p "$FORENSICS_DIR"
    DEADLINE=$(( $(date +%s) + LIMIT ))
    EXTEND_UNTIL=0
    EXT=0
    # wd_procs -> "<hostpid>\t<cpu>\t<cmd>" per container process, cpu in
    # hundredths of a second from the ps TIME column (the floor reading;
    # wd_cpu_ticks overrides it with finer /proc ticks when available).
    # Plain `docker top` (no -o/--format) is used on purpose: `-o` is not a
    # docker-top option and would be forwarded to ps inconsistently. The
    # default ps -ef layout is UID PID PPID C STIME TTY TIME CMD, so $2 is
    # the HOST pid and $7 the cumulative CPU time.
    wd_procs() {
      docker top "$RENDER_CONTAINER" 2>/dev/null | awk '
        NR == 1 { next }
        NF >= 8 {
          pid = $2; tm = $7; cmd = $8
          for (i = 9; i <= NF; i++) cmd = cmd " " $i
          n = split(tm, a, ":"); sec = 0
          for (j = 1; j <= n; j++) sec = sec * 60 + (a[j] + 0)
          printf "%s\t%d\t%s\n", pid, sec * 100, cmd
        }'
    }
    # wd_cpu_ticks <pid> -> utime+stime clock ticks from /proc, or exit != 0.
    # Fields 1-2 (pid, comm) are stripped with ${s##*) } because comm may
    # contain spaces; utime/stime are then the 12th/13th remaining tokens.
    # A mismatched CONFIG_HZ only rescales the delta — the corroborator tests
    # the SIGN of the delta, never its magnitude, so it stays correct.
    wd_cpu_ticks() {
      local raw
      [ -r "$PROC_ROOT/$1/stat" ] || return 1
      raw=$(cat "$PROC_ROOT/$1/stat" 2>/dev/null) || return 1
      raw="${raw##*) }"
      awk -v s="$raw" 'BEGIN {
        n = split(s, f, /[ \t]+/)
        if (n < 13) exit 1
        t = f[12] + f[13]
        if (t !~ /^[0-9]+$/) exit 1
        print t
      }'
    }
    # wd_snapshot -> "<total_cpu>|<kernel_pid>|<kernel_cpu>", empty (status 1)
    # when the container exposes no process table at all (already gone, or
    # `docker top` unusable). That is deliberately NOT read as "dead": the
    # caller re-checks with wd_running before suppressing the report, and the
    # pre-v1.3.37 kill semantics stay reachable — fail-toward-today, never
    # fail-open into an unbounded run.
    wd_snapshot() {
      local procs pid cpu cmd total kpid kcpu ticks
      procs=$(wd_procs)
      [ -n "$procs" ] || return 1
      total=0; kpid=""; kcpu=0
      while IFS=$'\t' read -r pid cpu cmd; do
        [ -n "$pid" ] || continue
        ticks=$(wd_cpu_ticks "$pid") && cpu="$ticks"
        total=$(( total + cpu ))
        # Kernel-child patterns for the engines this fleet renders with
        # (python3/ipykernel, R/IRkernel, julia/IJulia, java jshell,
        # JS/deno kernel). DEV-EXP hung on a python3 kernel.
        case "$cmd" in
          *ipykernel*|*jupyter*|*IRkernel*|*IJulia*|*xeus*|*jshell*|*kernel.js*)
            kpid="$pid"; kcpu=$(( kcpu + cpu )) ;;
        esac
      done <<< "$procs"
      echo "$total|$kpid|$kcpu"
    }
    wd_running() {
      [ "$(docker inspect --format '{{.State.Running}}' "$RENDER_CONTAINER" 2>/dev/null)" = "true" ]
    }
    while true; do
      sleep "$WATCHDOG_POLL_SECS"
      NOW=$(date +%s)
      LOG_MTIME=0
      for f in "$RENDER_LOG" "$GITHUB_WORKSPACE/quarto-exec.log"; do
        [ -e "$f" ] || continue
        M=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo 0)
        [ "$M" -gt "$LOG_MTIME" ] && LOG_MTIME=$M
      done
      if [ "$LOG_MTIME" -eq 0 ]; then
        DEADLINE=$(( NOW + LIMIT ))  # no log yet: keep resetting (pull/startup grace)
        continue
      fi
      DEADLINE=$(( LOG_MTIME + LIMIT ))
      [ "$NOW" -le "$DEADLINE" ] && continue
      # Granted liveness extension still in force: stay quiet.
      [ "$NOW" -le "$EXTEND_UNTIL" ] && continue
      SILENT_MIN=$(( (NOW - LOG_MTIME) / 60 ))
      PAGE=$(sed 's/\x1b\[[0-9;]*m//g' "$RENDER_LOG" 2>/dev/null | grep -oE '\[[0-9]+/[0-9]+\]' | tail -1)
      [ -n "$PAGE" ] || PAGE="unknown"
      # ---- v1.3.37: corroborate BEFORE deciding --------------------------
      LIVE=0; LIVE_PID=""; LIVE_DELTA=0; HAVE_TABLE=1
      S1=$(wd_snapshot)
      S2=""
      if [ -n "$S1" ]; then
        sleep "$WATCHDOG_PROBE_SECS"
        S2=$(wd_snapshot)
      fi
      if [ -z "$S1" ] || [ -z "$S2" ]; then
        HAVE_TABLE=0
      else
        # Snapshot fields: 1=container-wide CPU, 2=kernel host PID,
        # 3=kernel-child CPU (all in hundredths-of-a-second units when
        # /proc is unreadable, native clock ticks when it is readable).
        IFS='|' read -r -a SN1 <<< "$S1"
        IFS='|' read -r -a SN2 <<< "$S2"
        D_ALL=$(( ${SN2[0]:-0} - ${SN1[0]:-0} ))
        D_KERN=$(( ${SN2[2]:-0} - ${SN1[2]:-0} ))
        K2="${SN2[1]:-}"
        # Kernel child present AND CPU accumulating (kernel-scoped delta,
        # or container-wide progress if the kernel itself is idle while
        # pandoc/typesetting burns CPU). Conservative toward NOT killing.
        if [ -n "$K2" ] && { [ "$D_KERN" -gt 0 ] || [ "$D_ALL" -gt 0 ]; }; then
          LIVE=1
          LIVE_PID="$K2"
          if [ "$D_KERN" -gt 0 ]; then LIVE_DELTA="$D_KERN"; else LIVE_DELTA="$D_ALL"; fi
        fi
      fi
      if [ "$LIVE" -eq 1 ] && [ "$EXT" -lt "$HANG_EXT_MAX" ]; then
        EXT=$(( EXT + 1 ))
        EXTEND_UNTIL=$(( $(date +%s) + WATCHDOG_EXTEND_SECS ))
        echo "::warning::LIVE-KERNEL-CORROBORATED pid=$LIVE_PID cpu-delta=$LIVE_DELTA silence=${SILENT_MIN}min page=${PAGE} — not killing; extension ${EXT}/${HANG_EXT_MAX} granted (+${WATCHDOG_EXTEND_SECS}s)"
        continue
      fi
      if [ "$LIVE" -eq 1 ]; then
        echo "::warning::LIVE-KERNEL-EXTENSIONS-EXHAUSTED after ${EXT} extension(s) (bound hang-max-extensions=${HANG_EXT_MAX}); proceeding to the documented kill path at page ${PAGE}"
      fi
      if [ "$HAVE_TABLE" -eq 0 ] && ! wd_running; then
        # The render finished (or died) on its own during the probe window.
        # Killing a gone container is a no-op, but raising HANG-DETECTED for a
        # render that actually completed would be a false error — stay quiet.
        echo "::notice::HANG-WATCHDOG-STOOD-DOWN: no process table and container not running after ${SILENT_MIN} min inactivity at page ${PAGE} — no kill issued"
        break
      fi
      echo "::error::HANG-DETECTED after ${SILENT_MIN} min inactivity at page ${PAGE}"
      {  # forensics BEFORE kill
        echo "=== hang-forensics $(date -Is): ${SILENT_MIN} min silent, page ${PAGE} ==="
        echo "=== v1.3.37 corroboration: live=$LIVE kernel-pid='${LIVE_PID:-none}' cpu-delta=${LIVE_DELTA:-n/a} container-table=$HAVE_TABLE action=$HANG_MODE extensions=$EXT/$HANG_EXT_MAX ==="
        echo '--- ps -ef (quarto|docker|jupyter) ---'
        ps -ef | grep -E 'quarto|docker|jupyter' | grep -v grep || true
        echo '--- docker ps -a (label=ebpro-render=true) ---'
        docker ps -a --filter label=ebpro-render=true || true
        echo "--- docker inspect $RENDER_CONTAINER ---"
        docker inspect --format '{{.State.Status}} started={{.State.StartedAt}} OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}}' "$RENDER_CONTAINER" || true
        # v1.3.38: memory attribution. Container is still alive here, so the
        # exec arm adds its OWN cgroup view (memory.max proves the bound is
        # in effect, memory.current the pressure at hang time); the helper arm
        # snapshots the sidecar counters alongside. Non-fatal by construction.
        capture_oom_attribution "hang-forensics page=${PAGE}" || true
        echo '--- in-container process list (ps, /proc cmdline fallback) ---'
        docker exec "$RENDER_CONTAINER" ps -ef 2>/dev/null || docker exec "$RENDER_CONTAINER" sh -c 'for d in /proc/[0-9]*; do printf "%s " "${d#/proc/}"; tr "\0" " " < "$d/cmdline" 2>/dev/null; echo; done' 2>/dev/null || true
        # v1.3.32: replaced the old 'kernel log tails' probe (/tmp/*kernel*.log,
        # ~/.local/share/jupyter/log/*), structurally ALWAYS empty: quarto spawns
        # kernels via /tmp connection files without --log-file, so no kernel log
        # file ever exists in the render container (proven on 3 live captures).
        # Observed hang signature is an idle chrome-headless-shell, so capture the
        # headless-chromium profile dirs and singleton locks instead. 'docker logs'
        # was evaluated and deliberately SKIPPED as a pure content duplicate of the
        # tee'd RENDER_LOG (container stdio is double-sunk: client pipe + daemon
        # json-file; local test 2026-10-17: same lines both sides, interleaving
        # order only); the 'tail -n 40 $RENDER_LOG' below already covers it.
        echo '--- chrome profile dirs + singleton locks (in-container) ---'
        docker exec "$RENDER_CONTAINER" bash -lc 'ls -lad /tmp/.org.chromium.* /tmp/*hrome* 2>/dev/null; find /tmp -maxdepth 2 -name "SingletonLock" -exec ls -la {} \; 2>/dev/null' || true
        echo "--- tail -n 40 $RENDER_LOG ---"
        tail -n 40 "$RENDER_LOG" || true
        echo '--- ls -la _freeze .quarto ---'
        ls -la "$GITHUB_WORKSPACE/_freeze" "$GITHUB_WORKSPACE/.quarto" || true
      } > "$FORENSICS_DIR/hang-report.txt" 2>&1
      # v1.3.37 (survivability, part 1): echo the report to the sidecar's
      # stdout so it lands in the RETAINED JOB LOG. Before this change the
      # whole forensics block was redirected into a file and only ever
      # APPENDED to $GITHUB_STEP_SUMMARY, so it appeared in neither the job
      # log nor the artifact until upload — and summary_url is null for these
      # jobs, so a quota-blocked upload made the report unrecoverable.
      # Nothing is enlarged: same bytes, one extra transport.
      cat "$FORENSICS_DIR/hang-report.txt" 2>/dev/null || true
      cat "$FORENSICS_DIR/hang-report.txt" >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true
      if [ "$HANG_MODE" = "report-only" ]; then
        echo "::warning::HANG-REPORT-ONLY page=${PAGE} silence=${SILENT_MIN}min: hang-action=report-only — docker kill SUPPRESSED, render left running; render-timeout-minutes is the remaining backstop"
      else
        docker kill "$RENDER_CONTAINER" >/dev/null 2>&1 || true
      fi
      echo "$PAGE" > "$GITHUB_WORKSPACE/.hang-detected" 2>/dev/null || true
      break
    done
  ) &
  WATCHDOG_PID=$!
fi
# <<< WATCHDOG-END
