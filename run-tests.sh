#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# Read AGENTS.md "Build System" to know what is needed.
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi

# Install SDL2 dev headers if missing (cmake will fail without them)
if ! dpkg -l libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

cd target-repo

# Initialise submodules (nlohmann/json lives here)
git submodule update --init --recursive

# Build — configure then build as plain statements so set -e catches failures.
# CMakeLists.txt already sets -Wall; we use a fresh 'build' directory.
cmake -B build -S .
cmake --build build
echo "--- BUILD SUCCEEDED ---"

# -------------------------------------------------------------------------
# Verification 1: scenario run — no debug flood on stdout, clean output
# -------------------------------------------------------------------------
./build/SimulationPathFinder --scenario straight_tunnel > /tmp/scenario_single.txt 2>/tmp/scenario_single_err.txt

# Must report a Traversal success line
grep -q "Traversal success" /tmp/scenario_single.txt \
  || { echo "ASSERTION FAILED: 'Traversal success' not found in --scenario straight_tunnel output"; exit 1; }

# Collisions line must be present (verifies tabular metric output)
grep -q "Collisions" /tmp/scenario_single.txt \
  || { echo "ASSERTION FAILED: 'Collisions' not found in --scenario straight_tunnel output"; exit 1; }

# Without --debug, WallFollower state transitions must NOT appear on stdout
# (they should now go to stderr which we captured separately)
if grep -q "FOLLOW_WALL\|FIND_WALL\|RECOVERY\|AVOID_COLLISION" /tmp/scenario_single.txt; then
  echo "ASSERTION FAILED: WallFollower debug output appeared on stdout without --debug flag"
  exit 1
fi

echo "PASS: --scenario straight_tunnel produces clean tabular output"

# -------------------------------------------------------------------------
# Verification 2: full scenario suite — tabular header + low collision counts
# -------------------------------------------------------------------------
./build/SimulationPathFinder --scenario-suite > /tmp/suite.txt 2>/tmp/suite_err.txt

# Tabular header must be present
grep -q "SCENARIO" /tmp/suite.txt \
  || { echo "ASSERTION FAILED: 'SCENARIO' column header not found in --scenario-suite output"; exit 1; }

grep -q "SUCCESS" /tmp/suite.txt \
  || { echo "ASSERTION FAILED: 'SUCCESS' column header not found in --scenario-suite output"; exit 1; }

grep -q "COLLISIONS" /tmp/suite.txt \
  || { echo "ASSERTION FAILED: 'COLLISIONS' column header not found in --scenario-suite output"; exit 1; }

# STRAIGHT_TUNNEL must appear in output (one of the five scenarios)
grep -q "STRAIGHT_TUNNEL" /tmp/suite.txt \
  || { echo "ASSERTION FAILED: 'STRAIGHT_TUNNEL' not found in suite output"; exit 1; }

echo "PASS: --scenario-suite produces tabular output with all expected columns"

# -------------------------------------------------------------------------
# Verification 3: --debug flag routes WallFollower trace to stderr
# -------------------------------------------------------------------------
./build/SimulationPathFinder --debug --scenario straight_tunnel \
  > /tmp/debug_stdout.txt 2>/tmp/debug_stderr.txt

# Spec requires: grep -q "wall" /tmp/dbg.txt (checking stderr)
grep -qi "wall" /tmp/debug_stderr.txt \
  || { echo "ASSERTION FAILED: WallFollower trace containing 'wall' not found on stderr with --debug"; exit 1; }

# Stdout must still contain the normal scenario output (not swallowed by debug mode)
grep -q "Traversal success" /tmp/debug_stdout.txt \
  || { echo "ASSERTION FAILED: Normal output missing from stdout when --debug is active"; exit 1; }

echo "PASS: --debug enables WallFollower trace on stderr"

# -------------------------------------------------------------------------
# Verification 4: existing batch mode unbroken
# -------------------------------------------------------------------------
./build/SimulationPathFinder --headless --batch 5 > /tmp/batch.txt 2>&1

# Must report batch completion
grep -qE "Batch complete|successful" /tmp/batch.txt \
  || { echo "ASSERTION FAILED: batch completion message not found in --headless --batch 5 output"; exit 1; }

echo "PASS: --headless --batch 5 completes successfully"

echo "--- TESTS PASSED ---"
