#!/bin/bash
set -euo pipefail

# -- Sandbox dependencies -------------------------------------------------
# Detect and install any system packages required to build.
# Project requires: cmake, build-essential, git, libsdl2-dev (SDL2 visualization)
# nlohmann/json is a git submodule — no system package needed.
if ! command -v cmake &>/dev/null; then
  apt-get update -qq && apt-get install -y --no-install-recommends \
    cmake build-essential git libsdl2-dev
fi

# Also ensure libsdl2-dev is present even if cmake is already installed
# (the sandbox may have cmake but not SDL2)
if ! dpkg -s libsdl2-dev &>/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y --no-install-recommends libsdl2-dev
fi
# -------------------------------------------------------------------------

# Initialise submodules if present (nlohmann/json lives in external/json)
cd target-repo
git submodule update --init --recursive

# Build
cmake -B cmake-build-debug -S .
cmake --build cmake-build-debug

# Test: run a headless batch of 5 simulations and verify the summary
mkdir -p test_output
./cmake-build-debug/SimulationPathFinder --headless --batch 5 --output-dir ./test_output/

echo ""
echo "=== Batch summary ==="
cat test_output/batch_summary.txt

echo ""
echo "=== Verifying non-trivial averages ==="
python3 - <<'PYEOF'
import sys, re

with open("test_output/batch_summary.txt") as f:
    content = f.read()

print(content)

def extract(pattern):
    m = re.search(pattern, content)
    if not m:
        print(f"ERROR: pattern not found: {pattern}", file=sys.stderr)
        sys.exit(1)
    return float(m.group(1))

avg_completion = extract(r"Average completion:\s*([\d.]+)")
avg_steps      = extract(r"Average steps:\s*([\d.]+)")
avg_distance   = extract(r"Average distance:\s*([\d.]+)")
total_samples  = extract(r"Total training samples:\s*([\d.]+)")

failures = []
if avg_completion <= 0:
    failures.append(f"avg_completion_percent = {avg_completion} (expected > 0)")
if avg_steps <= 0:
    failures.append(f"avg_steps = {avg_steps} (expected > 0)")
if avg_distance <= 0:
    failures.append(f"avg_distance_cm = {avg_distance} (expected > 0)")
if total_samples <= 0:
    failures.append(f"total_samples = {total_samples} (expected > 0)")

if failures:
    print("FAIL — non-trivial averages check failed:", file=sys.stderr)
    for f in failures:
        print(f"  {f}", file=sys.stderr)
    sys.exit(1)

print("PASS — all averages are non-trivial.")
PYEOF
