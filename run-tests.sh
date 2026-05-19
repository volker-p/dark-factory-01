#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# SimulationPathFinder requires cmake, build-essential, and libsdl2-dev.
# nlohmann/json is bundled as a git submodule (no system package needed).
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi

# Also ensure libsdl2-dev is present even if cmake already exists
if ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules (nlohmann/json lives in external/json)
cd target-repo
git submodule update --init --recursive

# -- Build ----------------------------------------------------------------
mkdir -p cmake-build-debug
cmake -B cmake-build-debug -S .
cmake --build cmake-build-debug
# -------------------------------------------------------------------------

# -- Tests ----------------------------------------------------------------
# 1. Existing batch smoke test (verifies nothing regressed)
mkdir -p test_output
./cmake-build-debug/SimulationPathFinder --batch 2 --headless --output-dir ./test_output/

# 2. Single scenario smoke test
./cmake-build-debug/SimulationPathFinder --scenario straight_tunnel

# 3. Full scenario suite
./cmake-build-debug/SimulationPathFinder --scenario-suite
# -------------------------------------------------------------------------
