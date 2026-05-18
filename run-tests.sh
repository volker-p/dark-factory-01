#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# Read CLAUDE.md "Build System" for what is needed.
# Use `apt-get install -y --no-install-recommends` for Debian/Ubuntu sandboxes.
# Always install: cmake build-essential git
# Project-specific: libsdl2-dev (SDL2 visualization library)
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi
# SDL2 may be missing even when cmake is present (fresh sandbox)
if ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present (nlohmann/json lives in external/json)
cd target-repo
git submodule update --init --recursive

# Build (from CLAUDE.md ## Build System)
cmake -B cmake-build-debug -S .
cmake --build cmake-build-debug

# Verify executable was produced
if [ ! -f "cmake-build-debug/SimulationPathFinder" ]; then
  echo "ERROR: executable not found after build" >&2
  exit 1
fi

# ---- Functional test: headless batch run --------------------------------
# Run 5 simulations headless; must exit 0 and produce a non-trivial summary.
OUTPUT_DIR="./test_output_ci"
rm -rf "$OUTPUT_DIR"

./cmake-build-debug/SimulationPathFinder --headless --batch 5 --output-dir "$OUTPUT_DIR"

SUMMARY="$OUTPUT_DIR/batch_summary.txt"

if [ ! -f "$SUMMARY" ]; then
  echo "ERROR: batch_summary.txt not found at $SUMMARY" >&2
  exit 1
fi

echo ""
echo "=== Batch summary ==="
cat "$SUMMARY"
echo ""

# Assert all averages are non-zero (spec requirement 4)
check_nonzero() {
  local label="$1"
  local pattern="$2"
  local value
  value=$(grep "$pattern" "$SUMMARY" | grep -oE '[0-9]+\.?[0-9]*' | head -1)
  if [ -z "$value" ] || [ "$(echo "$value > 0" | bc -l)" -eq 0 ]; then
    echo "ERROR: $label is zero or missing in summary (value='$value')" >&2
    exit 1
  fi
  echo "OK: $label = $value"
}

check_nonzero "avg_completion_percent" "Average completion:"
check_nonzero "avg_steps"              "Average steps:"
check_nonzero "avg_distance_cm"        "Average distance:"
check_nonzero "total_samples"          "Total training samples:"

echo ""
echo "=== All tests passed ==="
