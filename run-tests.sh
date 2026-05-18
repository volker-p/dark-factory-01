#!/usr/bin/env bash
set -euo pipefail

cd target-repo

# ── 1. Initialise submodules (nlohmann/json) ──────────────────────────────────
git submodule update --init --recursive

# ── 2. Install SDL2 if not already present ────────────────────────────────────
if ! dpkg -s libsdl2-dev >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y --no-install-recommends libsdl2-dev
fi

# ── 3. Configure and build (clean build dir to catch stale artefacts) ─────────
rm -rf cmake-build-debug
mkdir -p cmake-build-debug
cmake -B cmake-build-debug -S . -DCMAKE_CXX_FLAGS="-Wall -Werror"
cmake --build cmake-build-debug -- -j"$(nproc)"

# Confirm executable exists
if [ ! -f "cmake-build-debug/SimulationPathFinder" ]; then
    echo "ERROR: executable not produced" >&2
    exit 1
fi

# ── 4. Headless batch integration test ────────────────────────────────────────
TEST_OUT="$(mktemp -d)"
trap 'rm -rf "$TEST_OUT"' EXIT

echo ""
echo "=== Running headless batch (5 runs) ==="
./cmake-build-debug/SimulationPathFinder \
    --batch 5 \
    --headless \
    --output-dir "${TEST_OUT}/"

SUMMARY="${TEST_OUT}/batch_summary.txt"

if [ ! -f "$SUMMARY" ]; then
    echo "ERROR: batch_summary.txt not found at ${SUMMARY}" >&2
    exit 1
fi

echo ""
echo "=== batch_summary.txt ==="
cat "$SUMMARY"
echo ""

# Parse and assert all averages are > 0
check_nonzero() {
    local label="$1"
    local pattern="$2"
    local value
    value=$(grep -oP "${pattern}" "$SUMMARY" | head -1)
    if [ -z "$value" ]; then
        echo "ERROR: could not find '${label}' in summary" >&2
        exit 1
    fi
    # Use awk for floating-point comparison
    if ! awk -v v="$value" 'BEGIN { if (v+0 > 0) exit 0; else exit 1 }'; then
        echo "ERROR: '${label}' is not > 0 (got: ${value})" >&2
        exit 1
    fi
    echo "PASS: ${label} = ${value}"
}

check_nonzero "avg_completion_percent" "(?<=Average completion: )[0-9.]+"
check_nonzero "avg_steps"              "(?<=Average steps: )[0-9.]+"
check_nonzero "avg_distance_cm"        "(?<=Average distance: )[0-9.]+"
check_nonzero "total_samples"          "(?<=Total training samples: )[0-9]+"

echo ""
echo "=== All tests passed ==="
