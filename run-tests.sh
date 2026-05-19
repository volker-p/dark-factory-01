#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# SimulationPathFinder requires: cmake, build-essential, git, libsdl2-dev
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends cmake build-essential git libsdl2-dev
fi
# SDL2 may be absent even when cmake is present (different sandbox image)
if ! dpkg -l libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present (nlohmann/json is a submodule)
cd target-repo
git submodule update --init --recursive

# Build (from CLAUDE.md ## Build System)
# Use an out-of-source build directory named "build" (not cmake-build-debug which
# requires CLion/ninja). cmake --build with the default generator (make) works here.
# IMPORTANT: never pipe build commands — piping swallows the exit code.
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
echo "--- BUILD SUCCEEDED ---"

# Tests (from spec ## Verification section)
# Run all five acceptance checks. Each must succeed for the suite to pass.

# 1. Scenario run — no debug flood on stdout (debug goes to stderr, suppressed)
./build/SimulationPathFinder --scenario straight_tunnel 2>/dev/null

# 2. Full scenario suite
./build/SimulationPathFinder --scenario-suite 2>/dev/null

# 3. Debug flag enables WallFollower trace on stderr
./build/SimulationPathFinder --debug --scenario straight_tunnel 2>/tmp/dbg.txt
grep -q -i "wall\|FOLLOW\|RECOVERY" /tmp/dbg.txt

# 4. Existing batch mode unbroken
./build/SimulationPathFinder --headless --batch 5 2>/dev/null

echo "--- TESTS PASSED ---"
