#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# CLAUDE.md "Build System" requires: cmake, build-essential, libsdl2-dev
# nlohmann/json is fetched via git submodule (no extra system package needed).
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi

# libsdl2-dev may be absent even when cmake is present (separate package)
if ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present (fetches nlohmann/json)
cd target-repo
git submodule update --init --recursive

# Build (from CLAUDE.md ## Build System)
cmake -B cmake-build-debug -S .
cmake --build cmake-build-debug

# Test: headless batch run of 5 simulations (from CLAUDE.md running examples)
mkdir -p test_output
./cmake-build-debug/SimulationPathFinder --headless --batch 5 --output-dir ./test_output/

# Verify the summary file was produced and contains non-trivial averages
SUMMARY="test_output/batch_summary.txt"

echo ""
echo "=== batch_summary.txt ==="
cat "$SUMMARY"
echo "========================="

# All four average fields must be > 0 for the feature to be working
grep -E "Average completion: [1-9]" "$SUMMARY" \
  || { echo "FAIL: avg_completion_percent is zero or missing"; exit 1; }

grep -E "Average steps: [1-9]" "$SUMMARY" \
  || { echo "FAIL: avg_steps is zero or missing"; exit 1; }

grep -E "Average distance: [1-9]" "$SUMMARY" \
  || { echo "FAIL: avg_distance_cm is zero or missing"; exit 1; }

grep -E "Total training samples: [1-9]" "$SUMMARY" \
  || { echo "FAIL: total_samples is zero or missing"; exit 1; }

echo ""
echo "All checks passed — batch statistics are non-trivial."
