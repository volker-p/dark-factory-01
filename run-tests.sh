#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# Read AGENTS.md "External Dependencies" to know what is needed.
# Use `apt-get install -y --no-install-recommends` for Debian/Ubuntu sandboxes.
# Always install: cmake build-essential git
# Add language/project-specific packages (libsdl2-dev for SDL2 visualization).
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi
# Ensure libsdl2-dev is present even when cmake is already installed
if ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present (provides nlohmann/json header)
cd target-repo
git submodule update --init --recursive

# Build (from CLAUDE.md ## Build System)
cmake -B cmake-build-debug -S .
cmake --build cmake-build-debug

# Verify the executable was produced
if [ ! -f cmake-build-debug/SimulationPathFinder ]; then
  echo "ERROR: executable cmake-build-debug/SimulationPathFinder not found after build" >&2
  exit 1
fi

echo ""
echo "=== Test 1: single scenario (straight_tunnel) ==="
./cmake-build-debug/SimulationPathFinder --scenario straight_tunnel 2>/dev/null

echo ""
echo "=== Test 2: single scenario (corner_right) ==="
./cmake-build-debug/SimulationPathFinder --scenario corner_right 2>/dev/null

echo ""
echo "=== Test 3: scenario suite ==="
./cmake-build-debug/SimulationPathFinder --scenario-suite 2>/dev/null

echo ""
echo "=== Test 4: suite traversal success check ==="
SUITE_OUTPUT=$(./cmake-build-debug/SimulationPathFinder --scenario-suite 2>/dev/null)
echo "$SUITE_OUTPUT"

PASS_COUNT=$(echo "$SUITE_OUTPUT" | grep -c "YES" || true)
if [ "$PASS_COUNT" -lt 5 ]; then
  echo ""
  echo "FAIL: only $PASS_COUNT/5 scenarios reported traversal success (expected 5)" >&2
  exit 1
fi
echo ""
echo "PASS: all 5 scenarios reported traversal success"

echo ""
echo "=== Test 5: invalid scenario name returns error ==="
if ./cmake-build-debug/SimulationPathFinder --scenario bad_name >/dev/null 2>&1; then
  echo "FAIL: expected non-zero exit code for unknown scenario name" >&2
  exit 1
fi
echo "PASS: unknown scenario name correctly rejected"

echo ""
echo "=== Test 6: batch smoke-test (regression for random-maze path) ==="
mkdir -p /tmp/spf_test_out
./cmake-build-debug/SimulationPathFinder --batch 2 --headless \
  --output-dir /tmp/spf_test_out/ 2>/dev/null
echo "PASS: batch run completed without error"

echo ""
echo "=== All tests passed ==="
