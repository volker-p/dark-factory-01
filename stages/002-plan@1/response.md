Both files are written. Here's a summary of what was produced:

---

## What Was Done

### 1. Spec analysis (`specs/simulation-path-finder/batch-statistics.md`)
- **Target repo:** `volker-p/SimulationPathFinder` (cloned into `target-repo/`)
- **Type:** feature
- **Core problem:** `BatchSimulation::runBatch()` tracks successful run count but throws away all per-run metrics — the `BatchResults` struct fields `avg_completion_percent`, `avg_steps`, `avg_distance_cm`, and `total_samples` are always zero.

### 2. Code archaeology findings
- `Simulation` holds `metrics` (`PerformanceMetrics*`), `robot` (`Robot*`), and `logger` (`DataLogger*`) as private `unique_ptr` members — all populated after each run
- `PerformanceMetrics` already has `getCompletionPercent()`; `Robot` already has `getTotalDistance()` and `current_step` is exposed via `getCurrentStep()`
- `DataLogger` tracks `step_count` but **never exposes it** — the only missing piece
- `BatchSimulation` discards the `Simulation` object after each run without reading anything from it

### 3. `plan.md` — 5 targeted changes across 4 files
| File | Change |
|---|---|
| `include/DataLogger.h` | Add `getSampleCount()` getter |
| `include/Simulation.h` | Add 4 getter declarations |
| `src/Simulation.cpp` | Implement 3 non-inline getters |
| `src/BatchSimulation.cpp` | Accumulate metrics in loop, compute averages after |

### 4. `run-tests.sh`
- Installs `cmake`, `build-essential`, `git`, and `libsdl2-dev` if missing
- Initialises git submodules (`nlohmann/json`)
- Configures and builds via CMake
- Runs a 5-run headless batch and uses a Python snippet to assert all four averages in `batch_summary.txt` are `> 0`