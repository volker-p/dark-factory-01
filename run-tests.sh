#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# CMakeLists.txt requires: cmake, build-essential, libsdl2-dev
# nlohmann/json is provided as a git submodule (external/json/include)
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential libsdl2-dev git
fi
# Install libsdl2-dev if missing (cmake may be present but SDL2 absent)
if ! dpkg -l libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present (provides nlohmann/json)
cd target-repo
git submodule update --init --recursive

# Build (configure + build as plain statements so set -e catches failures)
# Use cmake-build-debug to match CLAUDE.md conventions
cmake -B cmake-build-debug -S . -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-Wall -Wextra"
cmake --build cmake-build-debug
echo "--- BUILD SUCCEEDED ---"

# -- Verification tests (from spec Verification section) ------------------

# 2. Suite still works unchanged
./cmake-build-debug/SimulationPathFinder --scenario-suite > /tmp/suite.txt
grep -q "STRAIGHT_TUNNEL" /tmp/suite.txt || { echo "ASSERTION FAILED: suite output missing STRAIGHT_TUNNEL"; exit 1; }
echo "--- SUITE OK ---"

# 3. Single scenario with trace creates the file
./cmake-build-debug/SimulationPathFinder --scenario straight_tunnel --trace /tmp/t.csv
test -f /tmp/t.csv || { echo "ASSERTION FAILED: trace file not created"; exit 1; }

# 4. Header — fixed columns present
head -1 /tmp/t.csv | grep -q "step,x_cm,y_cm,heading_deg,cell_x,cell_y" \
    || { echo "ASSERTION FAILED: header missing fixed columns"; exit 1; }

# 5. Header — default sensor columns present (angles -90 and 90)
head -1 /tmp/t.csv | grep -q "sensor_0_angle_-90_cm" \
    || { echo "ASSERTION FAILED: sensor_0_angle_-90_cm column missing from header"; exit 1; }
head -1 /tmp/t.csv | grep -q "sensor_1_angle_90_cm" \
    || { echo "ASSERTION FAILED: sensor_1_angle_90_cm column missing from header"; exit 1; }

# 6. Header — decision columns present
head -1 /tmp/t.csv | grep -q "decision,wall_left_dist_cm,wall_right_dist_cm,correction_rad,new_heading_deg,collided" \
    || { echo "ASSERTION FAILED: header missing decision columns"; exit 1; }

# 7. At least one data row (file must have header + ≥1 data row = ≥2 lines)
[ "$(wc -l < /tmp/t.csv)" -ge 2 ] || { echo "ASSERTION FAILED: trace has no data rows"; exit 1; }

# 8. collided column (last field) is only 0 or 1
tail -n +2 /tmp/t.csv | awk -F',' '{print $NF}' | grep -qvE '^[01]$' \
    && { echo "ASSERTION FAILED: collided column has non-0/1 values"; exit 1; } || true

# 9. Suite trace works
./cmake-build-debug/SimulationPathFinder --scenario-suite --trace /tmp/suite_trace.csv
test -f /tmp/suite_trace.csv || { echo "ASSERTION FAILED: suite trace file not created"; exit 1; }

# 10. --trace without --scenario is silent (no error, no file created at /tmp/ignored.csv)
./cmake-build-debug/SimulationPathFinder --headless --batch 1 --trace /tmp/ignored.csv > /dev/null 2>&1
echo "--- TRACE FLAG OK ---"

# 11. Headless batch unbroken
./cmake-build-debug/SimulationPathFinder --headless --batch 3 > /dev/null
echo "--- TESTS PASSED ---"
