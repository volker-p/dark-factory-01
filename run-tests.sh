#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# CMakeLists.txt requires: cmake, build-essential, libsdl2-dev
# External deps: nlohmann/json (git submodule, no install needed)
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential libsdl2-dev git
elif ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules (nlohmann/json is a submodule under external/json)
cd target-repo
git submodule update --init --recursive

# Configure (out-of-source build in cmake-build-debug, matching project convention)
mkdir -p cmake-build-debug
cmake -S . -B cmake-build-debug -DCMAKE_BUILD_TYPE=Debug
echo "--- CMAKE CONFIGURE SUCCEEDED ---"

# Build — plain statement so set -e catches failures
cmake --build cmake-build-debug --parallel
echo "--- BUILD SUCCEEDED ---"

# --------------------------------------------------------------------------
# Verification step 1: grep assertions on source (no old relative-turn flags)
# Spec R5 / Verification item 5: no relative-turn flags in WallFollower.cpp
echo "--- Checking for banned symbols in WallFollower.cpp ---"
if grep -n "turn_left\|turn_right\|deltaTheta" src/WallFollower.cpp; then
  echo "ASSERTION FAILED: relative-turn flags found in WallFollower.cpp"
  exit 1
fi
echo "PASS: no relative-turn flags found"

# Verification: new Config fields must be present
echo "--- Checking Config.h for required fields ---"
grep -q "wall_follow_kp"           include/Config.h || { echo "ASSERTION FAILED: wall_follow_kp missing from Config.h"; exit 1; }
grep -q "wall_target_distance_cm"  include/Config.h || { echo "ASSERTION FAILED: wall_target_distance_cm missing from Config.h"; exit 1; }
grep -q "angle_tolerance_rad"      include/Config.h || { echo "ASSERTION FAILED: angle_tolerance_rad missing from Config.h"; exit 1; }
echo "PASS: all three config fields present in Config.h"

# --------------------------------------------------------------------------
# Verification step 3: straight_tunnel scenario must succeed
echo "--- Running scenario: straight_tunnel ---"
./cmake-build-debug/SimulationPathFinder --scenario straight_tunnel > /tmp/straight_tunnel.txt
cat /tmp/straight_tunnel.txt
grep -q "Traversal success.*YES" /tmp/straight_tunnel.txt || {
  echo "ASSERTION FAILED: straight_tunnel did not report Traversal success: YES"
  exit 1
}
echo "PASS: straight_tunnel Traversal success: YES"

# Verification step 4a: corner_right scenario must succeed
echo "--- Running scenario: corner_right ---"
./cmake-build-debug/SimulationPathFinder --scenario corner_right > /tmp/corner_right.txt
cat /tmp/corner_right.txt
grep -q "Traversal success.*YES" /tmp/corner_right.txt || {
  echo "ASSERTION FAILED: corner_right did not report Traversal success: YES"
  exit 1
}
echo "PASS: corner_right Traversal success: YES"

# Verification step 4b: corner_left scenario must succeed
echo "--- Running scenario: corner_left ---"
./cmake-build-debug/SimulationPathFinder --scenario corner_left > /tmp/corner_left.txt
cat /tmp/corner_left.txt
grep -q "Traversal success.*YES" /tmp/corner_left.txt || {
  echo "ASSERTION FAILED: corner_left did not report Traversal success: YES"
  exit 1
}
echo "PASS: corner_left Traversal success: YES"

# Verification: full scenario-suite table runs without crash and contains expected headers
echo "--- Running scenario-suite ---"
./cmake-build-debug/SimulationPathFinder --scenario-suite > /tmp/suite.txt
cat /tmp/suite.txt
grep -q "SCENARIO" /tmp/suite.txt || {
  echo "ASSERTION FAILED: scenario-suite output missing SCENARIO header"
  exit 1
}
grep -q "SUCCESS" /tmp/suite.txt || {
  echo "ASSERTION FAILED: scenario-suite output missing SUCCESS column"
  exit 1
}
grep -q "STRAIGHT_TUNNEL" /tmp/suite.txt || {
  echo "ASSERTION FAILED: scenario-suite output missing STRAIGHT_TUNNEL row"
  exit 1
}
echo "PASS: scenario-suite ran and table is present"

# Smoke test: batch headless run completes without crash
echo "--- Running batch smoke test (2 runs, headless) ---"
./cmake-build-debug/SimulationPathFinder --batch 2 --headless --output-dir /tmp/smoke_output/ > /tmp/smoke.txt
cat /tmp/smoke.txt
grep -q "Simulation complete" /tmp/smoke.txt || {
  echo "ASSERTION FAILED: batch smoke test did not print 'Simulation complete'"
  exit 1
}
echo "PASS: batch smoke test completed"

echo "--- TESTS PASSED ---"
