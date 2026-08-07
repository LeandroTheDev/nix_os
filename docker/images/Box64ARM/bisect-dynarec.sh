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

set -u

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
  local out
  # Capture full output (not piped straight to grep) so we can check for
  # the failure line and the success line independently, even though the
  # process gets killed by `timeout` once it reaches the UPnP step (PZ's
  # startup can hang there depending on the router, which is expected and
  # not what we're testing for here).
  out=$(BOX64_NODYNAREC="$range" timeout 90 "${prog[@]}" 2>&1)

  if echo "$out" | grep -q "Failed to connect to Steam servers"; then
    return 1   # reached the Steam step and it failed -> bug still present
  fi
  # Reaching the UPnP line means it got past Steam connection successfully.
  echo "$out" | grep -q "If the server hangs here, set UPnP=false."
}

lo=$((start))
hi=$((end))

full_range=$(printf '0x%x-0x%x' "$lo" "$hi")
echo "Sanity check: disabling the full range $full_range ..."
if ! bug_is_fixed "$full_range"; then
  echo "Bug NOT fixed even with the full range disabled." >&2
  echo "Either the range doesn't cover the culprit, or this isn't a DynaRec bug." >&2
  exit 1
fi
echo "Confirmed: culprit is within $full_range. Bisecting..."

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
