#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# SimulationPathFinder requires: cmake, build-essential, libsdl2-dev
# nlohmann/json is vendored as a git submodule (no extra package needed).
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential libsdl2-dev
fi

# Ensure libsdl2-dev is present even when cmake is already installed
if ! dpkg -l libsdl2-dev 2>/dev/null | grep -q '^ii'; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules (nlohmann/json)
cd target-repo
git submodule update --init --recursive

# Build (from CLAUDE.md ## Build System)
cmake -B cmake-build-debug -S .
cmake --build cmake-build-debug

# Test: headless batch run must exit 0 and produce a non-trivial summary
./cmake-build-debug/SimulationPathFinder --headless --batch 5 --output-dir ./test_output/

# Verify all batch statistics are non-zero
SUMMARY=test_output/batch_summary.txt
if [ ! -f "$SUMMARY" ]; then
  echo "ERROR: batch_summary.txt not found"
  exit 1
fi

echo ""
echo "=== Batch summary ==="
cat "$SUMMARY"
echo ""

# Extract values and assert they are > 0
avg_completion=$(grep "Average completion" "$SUMMARY" | grep -oP '[\d.]+' | head -1)
avg_steps=$(grep "Average steps"          "$SUMMARY" | grep -oP '[\d.]+' | head -1)
avg_distance=$(grep "Average distance"    "$SUMMARY" | grep -oP '[\d.]+' | head -1)
total_samples=$(grep "Total training"     "$SUMMARY" | grep -oP '[0-9]+'  | head -1)

echo "avg_completion_percent : $avg_completion"
echo "avg_steps              : $avg_steps"
echo "avg_distance_cm        : $avg_distance"
echo "total_samples          : $total_samples"

PASS=1
[ "$(echo "$avg_completion > 0" | bc -l)" -eq 1 ] || { echo "FAIL: avg_completion_percent is 0"; PASS=0; }
[ "$(echo "$avg_steps > 0"      | bc -l)" -eq 1 ] || { echo "FAIL: avg_steps is 0"; PASS=0; }
[ "$(echo "$avg_distance > 0"   | bc -l)" -eq 1 ] || { echo "FAIL: avg_distance_cm is 0"; PASS=0; }
[ "${total_samples:-0}" -gt 0 ]                   || { echo "FAIL: total_samples is 0"; PASS=0; }

if [ "$PASS" -eq 1 ]; then
  echo "All batch statistics are non-zero — PASS"
else
  exit 1
fi
