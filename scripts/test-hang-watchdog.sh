#!/usr/bin/env bash
#
# test-hang-watchdog.sh — behavioural harness for the v1.3.37 hang-watchdog
# liveness corroborator inside .github/workflows/render-quarto.yml.
#
# WHAT IT DOES
#   Extracts the sidecar block verbatim between the
#     # >>> WATCHDOG-BEGIN / # <<< WATCHDOG-END
#   sentinels (the END sentinel sits AFTER the guard's `fi`, so the extracted
#   unit includes the `hang-detection-minutes != 0` disabled-guard and case (d)
#   can exercise it). The three `${{ inputs.* }}` tokens are rewritten to
#   harness variables, then the block is sourced under bash with a fake `docker`
#   function in scope. Every tunable the block reads through `: "${V:=d}"`
#   (WATCHDOG_POLL_SECS, WATCHDOG_PROBE_SECS, WATCHDOG_EXTEND_SECS, PROC_ROOT)
#   is set from the environment, so the sidecar can be fast-forwarded to a
#   decision in a few wall-clock seconds instead of minutes.
#
#   The corroborator is driven purely through its seams: the fake `docker top`
#   emits ps-style rows whose TIME column advances on a per-call counter, so the
#   two probe samples differ by a controlled CPU delta. The assertions are on the
#   emitted markers (::warning::LIVE-KERNEL-CORROBORATED etc.) and on how many
#   times `docker kill` was invoked — NOT on the byte content of hang-report.txt.
#
# KNOWN LIMITATIONS (stated, not faked — see PR body too)
#   1. This harness asserts the delta LOGIC via the seams; it deliberately does
#      NOT assert hang-report.txt bytes. On a macOS dev host `date -Is` fails
#      (it is GNU-only) inside the forensics redirect, so report bytes are not a
#      portable oracle here. The `date -Is` failure is pre-existing, contained in
#      the `{ ... } > hang-report.txt 2>/dev/null` block, and non-fatal.
#   2. It runs the block's pure-shell parsing (the `${s##*) }` comm-strip, the
#      awk field math, the sign-of-delta verdict) under bash and therefore DOES
#      exercise wd_cpu_ticks when PROC_ROOT points at synthetic stat files. It
#      cannot, however, validate the GNU coreutils path a real linux runner takes
#      for `stat -c %Y` vs the BSD `stat -f %m` fallback (macOS only has the
#      latter), nor reproduce a real `docker run --rm` exiting 137 on kill.
#      For case (b) the harness asserts "`docker kill` invoked + the
#      `exit "$pipe_status"` branch is intact"; it does not simulate the 137.
#   3. MUST run under bash (the block uses `read -a`, arrays, herestrings). zsh's
#      `read -a` differs and will report a false LIVE=0. Invoke with `bash`.
#
# Exit status: 0 = every case passed, 1 = at least one failure.

set +e

# ---------------------------------------------------------------------------
# Locate the workflow under test (repo root = one level above this script).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/render-quarto.yml"

if [ ! -f "$WORKFLOW" ]; then
  echo "FATAL: cannot locate workflow at $WORKFLOW" >&2
  exit 1
fi

BEGIN_MARK='>>> WATCHDOG-BEGIN'
END_MARK='<<< WATCHDOG-END'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; kill_strays' EXIT

PASS=0
FAIL=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
note() { printf '       %s\n' "$1"; }

# Track every sidecar PID we spawn so EXIT cleanup can reap them.
SIDECARS=""
kill_strays() {
  for p in $SIDECARS; do kill_tree "$p"; done
}

# Recursive terminate (macOS/linux both have pgrep).
kill_tree() {
  local p="$1" c
  [ -z "$p" ] && return 0
  for c in $(pgrep -P "$p" 2>/dev/null); do kill_tree "$c"; done
  kill "$p" 2>/dev/null
  return 0
}

# ---------------------------------------------------------------------------
# Fake docker: behaviour driven by WD_MODE / WD_RUNNING. `top` advances a
# per-call counter so successive samples differ by a controlled CPU delta.
# ---------------------------------------------------------------------------
fmt_time() { printf '00:%02d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }

# When WD_PROC_ROOT is set with synthetic /proc-style stat files, wd_cpu_ticks
# overrides the ps TIME reading; we advance utime in step with the counter so
# the /proc path shows a live delta too.
write_proc_stat() {
  # $1=pid $2=comm $3=total_ticks(utime+stime) -> "<pid> (comm) S ppid ... <utime> <stime>"
  local pid="$1" comm="$2" t="$3"
  mkdir -p "$PROC_ROOT/$pid" 2>/dev/null
  # 13 tokens AFTER ") ": state..cmajflt(11) utime(12) stime(13).
  printf '%s (%s) S 1 1 1 1 1 1 1 1 1 1 %s %s 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1\n' \
    "$pid" "$comm" "$(( t / 2 ))" "$(( t - t / 2 ))" > "$PROC_ROOT/$pid/stat"
}

docker() {
  local sub="$1"; shift
  case "$sub" in
    top)
      local c; c=$(( $(cat "$WD_CTR") + 1 )); echo "$c" > "$WD_CTR"
      echo "UID PID PPID C STIME TTY TIME CMD"
      # empty_table models a finished/gone container: header line only, NO rows.
      [ "$WD_MODE" = empty_table ] || echo "root 4241 4200 0 10:00 ? 00:00:00 quarto render prof.qmd"
      case "$WD_MODE" in
        live_kernel|live_proc)
          echo "root 4242 4241 0 10:00 ? $(fmt_time "$c") python3 -m ipykernel_launcher -f /tmp/k.json"
          [ "$WD_MODE" = live_proc ] && write_proc_stat 4242 "python3" "$(( c * 100 ))"
          ;;
        idle_kernel)
          # kernel present but TIME never advances -> zero CPU delta
          echo "root 4242 4241 0 10:00 ? 00:00:05 python3 -m ipykernel_launcher -f /tmp/k.json"
          ;;
        no_kernel)
          echo "root 4242 4241 0 10:00 ? $(fmt_time "$c") pandoc --standalone in.md -o out.html"
          ;;
        empty_table)
          : ;;  # header only -> no process rows
      esac
      ;;
    inspect)
      # wd_running reads exactly "true"/"false"
      echo "$WD_RUNNING"
      ;;
    kill)
      echo x >> "$WD_KILLS"
      ;;
    ps|exec|*)
      : ;;  # forensics probes: inert
  esac
}

# ---------------------------------------------------------------------------
# Extract + substitute the sidecar block once, then verify it still parses.
# ---------------------------------------------------------------------------
BLOCK="$TMP/block.sh"
awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
  index($0,b){f=1;next} index($0,e){f=0} f
' "$WORKFLOW" \
| sed -e 's/${{ inputs.hang-detection-minutes }}/$CASE_HANG_MIN/g' \
      -e 's/${{ inputs.hang-action }}/$CASE_HANG_MODE/g' \
      -e 's/${{ inputs.hang-max-extensions }}/$CASE_HANG_EXT/g' > "$BLOCK"

# ---------------------------------------------------------------------------
# run_case NAME
# Reads: CASE_HANG_MIN/MODE/EXT, WATCHDOG_*_SECS, WD_MODE, WD_RUNNING,
#        CASE_WAIT. Writes the block's combined output to $OUT and the number
#        of docker-kill invocations to $KILLS.
# ---------------------------------------------------------------------------
run_case() {
  local name="$1"
  WS="$TMP/$name.ws"; mkdir -p "$WS"
  export GITHUB_WORKSPACE="$WS"
  export GITHUB_STEP_SUMMARY="$WS/summary.md"; : > "$GITHUB_STEP_SUMMARY"
  export RENDER_CONTAINER="fake-render-c"
  export RENDER_LOG="$WS/render.log"
  printf 'processing file\n[17/32] some-cell\n' > "$RENDER_LOG"
  # Backdate the log so the inactivity deadline is already blown on tick one.
  touch -t "$(date -v-200S +%Y%m%d%H%M.%S 2>/dev/null || date -d '200 seconds ago' +%Y%m%d%H%M.%S 2>/dev/null)" "$RENDER_LOG" 2>/dev/null
  [ -f "$RENDER_LOG" ] || { sleep 1; touch "$RENDER_LOG"; }

  export WD_CTR="$WS/ctr";   echo 0 > "$WD_CTR"
  export WD_KILLS="$WS/kills"; : > "$WD_KILLS"
  export PROC_ROOT="$WS/no-proc"; mkdir -p "$PROC_ROOT"   # absent => ps-TIME fallback

  OUT="$TMP/$name.out"; : > "$OUT"

  (
    source "$BLOCK" >>"$OUT" 2>&1
    SIDECAR="$WATCHDOG_PID"
    sleep "$CASE_WAIT"
    kill_tree "$SIDECAR"
    wait "$SIDECAR" 2>/dev/null
  )
  KILLS=$(wc -l < "$WD_KILLS" | tr -d ' ')
  [ -z "$KILLS" ] && KILLS=0
}

# convenience greps over the last case output
has()     { grep -qF -- "$1" "$OUT"; }
count()   { grep -cF -- "$1" "$OUT"; }

echo "======================================================================"
echo " Hang-watchdog liveness-corroboration harness (render-quarto.yml)"
echo "======================================================================"

# ---- sanity: extraction produced a parseable, token-free unit -------------
echo "[pre] block extraction"
if [ ! -s "$BLOCK" ]; then bad "sentinel extraction produced an empty block"; else ok "extracted $(wc -l < "$BLOCK" | tr -d ' ') lines between sentinels"; fi
if grep -q '\${{' "$BLOCK"; then bad "leftover \${{ ... }} token in extracted block"; else ok "all \${{ inputs.* }} tokens substituted"; fi
if bash -n "$BLOCK" 2>"$TMP/parse.err"; then ok "bash -n clean on extracted block"; else bad "bash -n: $(cat "$TMP/parse.err")"; fi
# the disabled-guard must be INSIDE the extracted unit (END sentinel after fi)
if grep -qF 'if [ -n "$HANG_MIN" ] && [ "$HANG_MIN" != "0" ]; then' "$BLOCK"; then
  ok "disabled-guard present in extracted unit (case d is meaningful)"
else
  bad "disabled-guard NOT inside sentinels — case (d) cannot exercise it"
fi
echo

# ---------------------------------------------------------------------------
# (a) live kernel + positive CPU delta  ->  no kill, LIVE-KERNEL-CORROBORATED
# ---------------------------------------------------------------------------
echo "[case a] live kernel + CPU delta > 0  =>  corroborated, NOT killed"
export CASE_HANG_MIN=1 CASE_HANG_MODE=kill CASE_HANG_EXT=3
export WATCHDOG_POLL_SECS=1 WATCHDOG_PROBE_SECS=0 WATCHDOG_EXTEND_SECS=300
export WD_MODE=live_kernel WD_RUNNING=true CASE_WAIT=4
run_case a
if has 'LIVE-KERNEL-CORROBORATED'; then ok "LIVE-KERNEL-CORROBORATED emitted"; else bad "no LIVE-KERNEL-CORROBORATED (see $OUT)"; fi
[ "$KILLS" = "0" ] && ok "docker kill invoked 0x (container spared)" || bad "docker kill invoked ${KILLS}x (should be 0)"
if has 'HANG-DETECTED'; then bad "HANG-DETECTED raised for a live kernel (false positive)"; else ok "no HANG-DETECTED"; fi
# annotation must name the live pid, the delta and the page it saw
if grep -qE 'LIVE-KERNEL-CORROBORATED pid=[0-9]+ cpu-delta=[1-9][0-9]* ' "$OUT"; then
  ok "corroboration names pid + positive cpu-delta"
else
  bad "corroboration line missing pid/cpu-delta detail"
fi
note "sample: $(grep -m1 LIVE-KERNEL-CORROBORATED "$OUT" | sed 's/ — not killing.*//')"
echo

# ---------------------------------------------------------------------------
# (a2 / bonus) liveness detected through the /proc tick path (PROC_ROOT seam)
# ---------------------------------------------------------------------------
echo "[case a2] live kernel via /proc ticks (PROC_ROOT seam, not ps TIME)"
export WD_MODE=live_proc CASE_WAIT=4
run_case a2
if has 'LIVE-KERNEL-CORROBORATED'; then ok "LIVE-KERNEL-CORROBORATED via /proc ticks"; else bad "/proc-tick path did not corroborate (see $OUT)"; fi
[ "$KILLS" = "0" ] && ok "docker kill invoked 0x on /proc-tick liveness" || bad "docker kill invoked ${KILLS}x (should be 0)"
echo

# ---------------------------------------------------------------------------
# (b) no kernel child  ->  HANG-DETECTED (unchanged) + docker kill + exit-path
# ---------------------------------------------------------------------------
echo "[case b] no kernel child  =>  HANG-DETECTED verbatim + docker kill"
export WD_MODE=no_kernel WD_RUNNING=true CASE_WAIT=3
run_case b
if has 'HANG-DETECTED after'; then ok "HANG-DETECTED raised"; else bad "no HANG-DETECTED (see $OUT)"; fi
# the emitted line must match the encoded v1.3.36 message shape exactly
if grep -qE '^::error::HANG-DETECTED after [0-9]+ min inactivity at page .+$' "$OUT"; then
  ok "HANG-DETECTED message shape preserved"
else
  bad "HANG-DETECTED message shape changed"
fi
note "sample: $(grep -m1 'HANG-DETECTED after' "$OUT")"
# the format string in the source block is byte-identical to the v1.3.36 contract
if grep -qF 'echo "::error::HANG-DETECTED after ${SILENT_MIN} min inactivity at page ${PAGE}"' "$BLOCK"; then
  ok "HANG-DETECTED format string untouched in source"
else
  bad "HANG-DETECTED format string altered in source"
fi
[ "$KILLS" != "0" ] && ok "docker kill invoked (${KILLS}x) on the no-kernel path" || bad "docker kill NOT invoked on no-kernel hang"
# the PIPESTATUS decider stays the sole step-status gate (not simulated: see header)
if grep -qF 'exit "$pipe_status"' "$WORKFLOW"; then
  ok "exit \"\$pipe_status\" branch intact in workflow (137 path un-simulated by design)"
else
  bad "exit \"\$pipe_status\" branch missing from workflow"
fi
if has 'LIVE-KERNEL-CORROBORATED'; then bad "corroborated a hang with no kernel child"; else ok "no false corroboration without a kernel"; fi
echo

# ---------------------------------------------------------------------------
# (b2 / bonus) kernel present but ZERO CPU delta  ->  still killed (sign test)
# ---------------------------------------------------------------------------
echo "[case b2] kernel present but zero CPU delta  =>  still killed (sign of delta, not presence)"
export WD_MODE=idle_kernel WD_RUNNING=true CASE_WAIT=3
run_case b2
[ "$KILLS" != "0" ] && ok "idle kernel (delta 0) was killed — corroborator tests delta sign, not mere presence" || bad "idle kernel was NOT killed (fails fail-toward-today)"
if has 'LIVE-KERNEL-CORROBORATED'; then bad "corroborated an idle kernel with zero delta"; else ok "no corroboration without a positive delta"; fi
echo

# ---------------------------------------------------------------------------
# (c) extensions terminate at the bound (hang-max-extensions)
# ---------------------------------------------------------------------------
echo "[case c] sustained liveness but extensions capped at hang-max-extensions=2"
export CASE_HANG_MIN=1 CASE_HANG_MODE=kill CASE_HANG_EXT=2
export WATCHDOG_POLL_SECS=1 WATCHDOG_PROBE_SECS=0 WATCHDOG_EXTEND_SECS=0   # extensions expire each tick
export WD_MODE=live_kernel WD_RUNNING=true CASE_WAIT=9
run_case c
NCORR=$(count 'LIVE-KERNEL-CORROBORATED')
if [ "$NCORR" = "2" ]; then ok "granted exactly ${NCORR} extension(s) == bound"; else bad "granted ${NCORR} extensions (expected 2)"; fi
if has 'LIVE-KERNEL-EXTENSIONS-EXHAUSTED'; then ok "LIVE-KERNEL-EXTENSIONS-EXHAUSTED at the bound"; else bad "no exhaustion marker (bound not enforced)"; fi
if has 'HANG-DETECTED after'; then ok "fell through to HANG-DETECTED once bound hit (hang stays bounded)"; else bad "did not fall through to kill after exhausting extensions"; fi
[ "$KILLS" != "0" ] && ok "docker kill invoked after extensions exhausted (${KILLS}x)" || bad "never killed after bound — hang would be unbounded"
note "$(grep -m1 LIVE-KERNEL-EXTENSIONS-EXHAUSTED "$OUT")"
echo

# ---------------------------------------------------------------------------
# (d) hang-detection-minutes: 0 disables the whole block (blast-radius guard)
# ---------------------------------------------------------------------------
echo "[case d] hang-detection-minutes=0  =>  watchdog fully disabled, zero side-effects"
export CASE_HANG_MIN=0 CASE_HANG_MODE=kill CASE_HANG_EXT=3
export WATCHDOG_POLL_SECS=1 WATCHDOG_PROBE_SECS=0 WATCHDOG_EXTEND_SECS=300
export WD_MODE=live_kernel WD_RUNNING=true CASE_WAIT=3
run_case d
if has 'Hang watchdog armed'; then bad "watchdog armed despite cap=0"; else ok "watchdog NOT armed (cap=0 guard honoured)"; fi
if has 'LIVE-KERNEL' || has 'HANG-DETECTED' || has 'HANG-WATCHDOG'; then bad "block produced markers on the disabled path"; else ok "no sidecar markers emitted"; fi
[ "$KILLS" = "0" ] && ok "docker kill invoked 0x (provably zero blast radius at cap=0)" || bad "docker kill invoked ${KILLS}x on disabled path"
echo

# ---------------------------------------------------------------------------
# (f / bonus) process table vanished + container gone  ->  stand down, no false error
# ---------------------------------------------------------------------------
echo "[case f] no process table AND container not running  =>  stand down (no false HANG-DETECTED)"
export CASE_HANG_MIN=1 CASE_HANG_MODE=kill CASE_HANG_EXT=3
export WATCHDOG_POLL_SECS=1 WATCHDOG_PROBE_SECS=0 WATCHDOG_EXTEND_SECS=300
export WD_MODE=empty_table WD_RUNNING=false CASE_WAIT=3
run_case f
if has 'HANG-WATCHDOG-STOOD-DOWN'; then ok "HANG-WATCHDOG-STOOD-DOWN emitted"; else bad "no stand-down marker (see $OUT)"; fi
if has 'HANG-DETECTED'; then bad "raised HANG-DETECTED for a render that already finished"; else ok "no false error for a completed render"; fi
[ "$KILLS" = "0" ] && ok "docker kill invoked 0x on stand-down" || bad "docker kill invoked ${KILLS}x on stand-down"
echo

# ---------------------------------------------------------------------------
# (e) cancellation survivability  ->  STATIC assertions on the if: strings
# ---------------------------------------------------------------------------
echo "[case e] cancellation survivability (static checks on workflow if: strings)"
# The forensics-carrying upload is the "Upload quarto execution log" step
# (its `path:` block already includes hang-forensics/). Capture the whole step.
UPLOAD_BLOCK=$(awk '
  /^      - name: Upload quarto execution log/{f=1}
  f && /^      - name:/ && !/Upload quarto execution log/{exit}
  f{print}
' "$WORKFLOW")
if echo "$UPLOAD_BLOCK" | grep -qF "if: always() && (failure() || cancelled())"; then
  ok "quarto-exec-log upload (carries hang-forensics/) runs on cancellation"
else
  bad "quarto-exec-log upload still excludes cancellation"
fi
if echo "$UPLOAD_BLOCK" | grep -qF "continue-on-error: true"; then
  ok "upload keeps continue-on-error: true (quota rejection cannot mask the error)"
else
  bad "upload lost continue-on-error: true"
fi
if echo "$UPLOAD_BLOCK" | grep -qF "hang-forensics/"; then
  ok "upload path still carries hang-forensics/ (path set unchanged)"
else
  bad "upload no longer carries hang-forensics/"
fi
if grep -qF "name: Ship hang forensics off-cluster" "$WORKFLOW"; then
  ok "off-cluster forensics step present"
  SHIP_IF=$(awk '/name: Ship hang forensics off-cluster/{f=1} f && /^      - name:/ && !/Ship hang/{exit} f{print}' "$WORKFLOW" | grep -m1 'if:')
  echo "$SHIP_IF" | grep -qF "if: always() && (failure() || cancelled())" \
    && ok "off-cluster ship gated on failure()||cancelled()" \
    || bad "off-cluster ship gate wrong: '$SHIP_IF'"
else
  bad "off-cluster forensics step missing"
fi
# the site-zip staging gate must be UNTOUCHED by this change
if grep -qF "if: inputs.site-transport != 'staging'" "$WORKFLOW"; then
  ok "site-zip staging gate still present (out-of-scope, untouched)"
else
  bad "site-zip staging gate disappeared — scope violation"
fi
echo

# ---------------------------------------------------------------------------
echo "======================================================================"
printf ' RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
echo "======================================================================"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
