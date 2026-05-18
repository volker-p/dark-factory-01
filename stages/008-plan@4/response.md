Both files are complete and correct. Here's a summary of what was produced:

---

## What was written

### `plan.md`

**Goal:** Expose final-run metrics from `Simulation` via getter methods, then use them in `BatchSimulation::runBatch()` to compute and store real averages in `BatchResults`.

**Files to change — only 3:**

| File | Change |
|---|---|
| `include/DataLogger.h` | Add `getSampleCount() const` getter returning private `step_count` |
| `include/Simulation.h` | Add 4 public getters: `getCompletionPercent()`, `getTotalSteps()`, `getTotalDistance()`, `getSampleCount()` — all delegating to already-owned members |
| `src/BatchSimulation.cpp` | Add 4 accumulators before the loop, read all 4 getters after each run, compute averages after the loop, remove the stale comment |

**Key design decisions captured in the plan:**
- Averages are computed over **successful runs only** (natural, avoids zero-distortion)
- `total_samples` accumulates across **all** runs (every run always writes CSV)
- Guard against `successful_runs == 0` to avoid divide-by-zero
- `DataLogger::close()` doesn't reset `step_count`, so getters are safe to call post-`run()`
- `saveSummary()` already uses all four fields — no changes needed there

### `run-tests.sh`

- Installs `cmake`, `build-essential`, `libsdl2-dev` if missing (checks both cmake and libsdl2-dev separately)
- Initialises the `nlohmann/json` submodule
- Configures and builds with CMake
- Runs `--headless --batch 5`
- Parses `batch_summary.txt` and asserts all four statistics are `> 0`