#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# Read AGENTS.md "External Dependencies" to know what is needed.
# Use `apt-get install -y --no-install-recommends` for Debian/Ubuntu sandboxes.
# Always install: cmake build-essential git
# Add language/project-specific packages (e.g. libsdl2-dev, default-jdk, nodejs).
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present
cd target-repo
git submodule update --init --recursive

# Build and test (from CLAUDE.md ## Build System)
cmake -B cmake-build-debug -S . -DCMAKE_CXX_FLAGS="-Wall -Wextra -Werror"
cmake --build cmake-build-debug -- -j"$(nproc)"

# Smoke-test: verify the binary runs and exits cleanly in headless batch mode
./cmake-build-debug/SimulationPathFinder --headless --batch 3

# Scenario suite: verify all five scenarios complete without crashing
./cmake-build-debug/SimulationPathFinder --scenario-suite

# Verify --debug flag sends output to stderr (stdout should remain clean)
./cmake-build-debug/SimulationPathFinder --debug --scenario straight_tunnel \
  2>/tmp/dbg_test.txt
grep -qi "wall\|RECOVERY\|FOLLOW\|FIND" /tmp/dbg_test.txt

echo "All tests passed."
