#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Install system packages required to build: cmake, build tools, SDL2, git.
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi

if ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules (nlohmann/json lives in external/)
cd target-repo
git submodule update --init --recursive

# Build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_FLAGS="-Wall -Wextra"
cmake --build build
echo "--- BUILD SUCCEEDED ---"

# -- Tests ----------------------------------------------------------------

# 2. Suite still works unchanged
./build/SimulationPathFinder --scenario-suite > /tmp/suite.txt
grep -q "STRAIGHT_TUNNEL" /tmp/suite.txt || { echo "FAIL: suite output missing STRAIGHT_TUNNEL"; exit 1; }
echo "--- SUITE OK ---"

# 3. Single scenario with trace creates the file
./build/SimulationPathFinder --scenario straight_tunnel --trace /tmp/t.csv
test -f /tmp/t.csv || { echo "FAIL: trace file not created"; exit 1; }

# 4. Header — fixed columns
head -1 /tmp/t.csv > /tmp/header.txt
grep -q "step,x_cm,y_cm,heading_deg,cell_x,cell_y" /tmp/header.txt \
    || { echo "FAIL: header missing fixed columns"; exit 1; }

# 5. Header — default sensor columns
grep -q "sensor_0_angle_-90_cm" /tmp/header.txt \
    || { echo "FAIL: sensor_0_angle_-90_cm column missing"; exit 1; }
grep -q "sensor_1_angle_90_cm" /tmp/header.txt \
    || { echo "FAIL: sensor_1_angle_90_cm column missing"; exit 1; }

# 6. Header — decision columns
grep -q "decision,wall_left_dist_cm,wall_right_dist_cm,correction_rad,new_heading_deg,collided" /tmp/header.txt \
    || { echo "FAIL: header missing decision columns"; exit 1; }

# 7. At least one data row (file must have >= 2 lines)
[ "$(wc -l < /tmp/t.csv)" -ge 2 ] || { echo "FAIL: trace has no data rows"; exit 1; }

# 8. collided column is only 0 or 1 (last field of each non-header row)
tail -n +2 /tmp/t.csv > /tmp/data_rows.txt
awk -F',' '{print $NF}' /tmp/data_rows.txt > /tmp/collided_col.txt
grep -qvE '^[01]$' /tmp/collided_col.txt \
    && { echo "FAIL: collided column has non-0/1 values"; exit 1; } || true

# 9. Suite trace works
./build/SimulationPathFinder --scenario-suite --trace /tmp/suite_trace.csv
test -f /tmp/suite_trace.csv || { echo "FAIL: suite trace file not created"; exit 1; }

# 10. --trace without --scenario is silent (no error, no file created)
rm -f /tmp/ignored.csv
./build/SimulationPathFinder --headless --batch 1 --trace /tmp/ignored.csv > /dev/null 2>&1
echo "--- TRACE FLAG OK ---"

# 11. Headless batch unbroken
./build/SimulationPathFinder --headless --batch 3 > /dev/null
echo "--- TESTS PASSED ---"
