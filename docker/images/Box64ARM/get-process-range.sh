#!/usr/bin/env bash
# Compute the full address range covered by all modules Box64 loaded,
# from the "Pre-allocated" lines in a BOX64_LOG=2 run. Use this as the
# starting range for bisect-dynarec.sh instead of the entire userspace
# range (0x0-0x7fffffffffff), which is correct but wastes bisection steps
# on address space nothing is loaded into.
#
# Usage:
#   BOX64_LOG=2 box64 <program> > box64.log 2>&1
#   ./get-process-range.sh box64.log

set -u
log=${1:?usage: $0 <box64-log-file>}

awk -v logfile="$log" '
  /Pre-allocated/ {
    for (i = 1; i <= NF; i++) {
      if ($i == "byte" && $(i-1) ~ /^0x/) size = strtonum($(i-1))
      if ($i == "at" && $(i+1) ~ /^0x/) { addr = strtonum($(i+1)); lib = $NF }
    }
    end = addr + size
    printf "0x%x-0x%x  (%s)\n", addr, end, lib
    if (min == "" || addr < min) min = addr
    if (max == "" || end > max) max = end
  }
  END {
    if (min == "") { print "No \"Pre-allocated\" lines found in " logfile > "/dev/stderr"; exit 1 }
    printf "\nFull process range: 0x%x-0x%x\n", min, max
  }
' "$log"
