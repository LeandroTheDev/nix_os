#!/usr/bin/env bash
# Binary-search the smallest BOX64_NODYNAREC address range whose exclusion
# from DynaRec fixes an observed bug (see BOX64Debugging.md, Step 4).
#
# Usage:
#   ./bisect-dynarec.sh <start_hex> <end_hex> -- <program> [args...]
#
# <start_hex>/<end_hex> is the initial range to search, e.g. the full
# userspace range (0x0-0x7fffffffffff) or the union of the "Pre-allocated"
# ranges reported by BOX64_LOG=2 (see get-process-range.sh).
#
# You MUST edit `bug_is_fixed` below to detect your actual success signal
# (exit code, a log line, a timeout that no longer triggers, etc). The
# default below is wired for Project Zomboid Dedicated Server's Steam
# connection failure — adjust the two grep patterns for your case.
#
# Strategy: rather than starting with the FULL range disabled (which is as
# slow as BOX64_DYNAREC=0 for the whole process — brutal for a JVM boot),
# this starts with a small window disabled at the low end of the range and
# doubles it ("galloping search") until the bug goes away. That gives a
# small bracket [start, found_hi) to hand to the normal binary-halving loop,
# so almost every test along the way runs with DynaRec mostly enabled and
# only a sliver disabled — fast — instead of paying the worst case up front.
#
# TIMEOUT_SECS (env var, default 180) is a safety-net max wait per attempt —
# bug_is_fixed kills the process as soon as it sees a matching log line, so
# this only kicks in if NEITHER pattern shows up (e.g. an unrelated crash).
# INITIAL_WIDTH (env var, default 0x10000) is the starting window size for
# the doubling phase — smaller starts cheaper but takes more doublings to
# reach a fixing width if the culprit is far from the low end of the range.
#
# IMPORTANT: <program> must `exec` into box64 (not just call it as the last
# line of a shell script). Without `exec`, the PID this script kills is the
# wrapper shell, not box64 — box64 (and the game it's running) would be left
# behind as an orphaned process still holding the server port open, breaking
# every subsequent iteration.

set -u

TIMEOUT_SECS=${TIMEOUT_SECS:-180}
INITIAL_WIDTH=${INITIAL_WIDTH:-0x10000}

if [ "$#" -lt 4 ] || [ "$3" != "--" ]; then
  echo "Usage: $0 <start_hex> <end_hex> -- <program> [args...]" >&2
  exit 2
fi

start=$1
end=$2
shift 3
prog=("$@")

bug_is_fixed() {
  local range=$1
  local logfile
  logfile=$(mktemp)

  BOX64_NODYNAREC="$range" "${prog[@]}" > "$logfile" 2>&1 &
  local pid=$!

  local verdict="timeout"
  local elapsed=0
  while [ "$elapsed" -lt "$TIMEOUT_SECS" ]; do
    if grep -q "Failed to connect to Steam servers" "$logfile" 2>/dev/null; then
      verdict="broken"
      break
    fi
    if grep -q "If the server hangs here, set UPnP=false." "$logfile" 2>/dev/null; then
      verdict="fixed"
      break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      verdict="exited"   # died on its own without hitting either pattern
      break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  # Whatever the verdict, stop the server now — it doesn't exit on its own
  # on the success path (a dedicated server just keeps running for players).
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null

  if [ "$verdict" = "exited" ] || [ "$verdict" = "timeout" ]; then
    echo "  (warning: neither pattern matched — verdict=$verdict, see $logfile)" >&2
    return 1
  fi
  rm -f "$logfile"
  [ "$verdict" = "fixed" ]
}

lo=$((start))
hi_full=$((end))
init_width=$((INITIAL_WIDTH))

# Step 0: confirm the bug actually reproduces with nothing disabled yet
# (fast — DynaRec fully enabled, this is the normal/broken run).
empty_range=$(printf '0x%x-0x%x' "$lo" "$lo")
if bug_is_fixed "$empty_range"; then
  echo "Bug already absent with DynaRec fully enabled — nothing to bisect." >&2
  echo "(check bug_is_fixed's detection patterns, or the bug isn't reliably reproducible)" >&2
  exit 1
fi
echo "Confirmed: bug reproduces with DynaRec fully enabled. Growing the disabled window..."

# Step 1: galloping search — double the disabled window from lo until it fixes
# the bug, instead of starting from the full (slow) range.
width=$init_width
prev_hi=$lo
hi=0
while :; do
  try_hi=$(( lo + width ))
  if [ "$try_hi" -ge "$hi_full" ]; then
    try_hi=$hi_full
  fi
  range=$(printf '0x%x-0x%x' "$lo" "$try_hi")
  echo "Growing: testing $range (width=0x$(printf '%x' "$width"))"
  if bug_is_fixed "$range"; then
    hi=$try_hi
    echo "  -> fixed at this width"
    break
  fi
  echo "  -> still broken"
  prev_hi=$try_hi
  if [ "$try_hi" -eq "$hi_full" ]; then
    break
  fi
  width=$(( width * 2 ))
done

if [ "$hi" -eq 0 ]; then
  echo "Bug NOT fixed even with the full range [$lo, $hi_full) disabled." >&2
  echo "Either the range doesn't cover the culprit, or this isn't a DynaRec bug." >&2
  exit 1
fi

lo_prev=$prev_hi
echo "Bracket found: [0x$(printf '%x' "$lo"), 0x$(printf '%x' "$hi")) fixes it, [0x$(printf '%x' "$lo"), 0x$(printf '%x' "$lo_prev")) does not."
echo "Bisecting within that bracket (much smaller than the full range)..."

# Stop once the window is small enough to hand off to BOX64_DYNAREC_TEST.
min_width=64

while [ $((hi - lo)) -gt "$min_width" ]; do
  mid=$(( lo + (hi - lo) / 2 ))
  lower_range=$(printf '0x%x-0x%x' "$lo" "$mid")
  echo "Testing lower half: $lower_range"
  if bug_is_fixed "$lower_range"; then
    hi=$mid
    echo "  -> fixed, culprit is in the lower half"
  else
    lo=$mid
    echo "  -> still broken, culprit is in the upper half"
  fi
done

final_range=$(printf '0x%x-0x%x' "$lo" "$hi")
echo
echo "Narrowed range: $final_range"
echo "Next step, find the exact diverging instruction:"
echo "  BOX64_DYNAREC_TEST=$final_range ${prog[*]} 2>&1 | tee dynarec_test.log"
