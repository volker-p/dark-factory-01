Both files are written. Here's a summary of what was produced:

---

## What Was Done

### 1. Spec analysis (`specs/simulation-path-finder/batch-statistics.md`)
- **`target_repo`**: `volker-p/SimulationPathFinder`
- **`type`**: `feature`
- **Core problem**: `BatchSimulation::runBatch()` accumulates `successful_runs` but leaves `avg_completion_percent`, `avg_steps`, `avg_distance_cm`, and `total_samples` at zero. The comment in the code says "would need to expose more metrics" — which is exactly what we'll fix.

### 2. Key findings from the codebase
| Finding | Impact |
|---|---|
| `Simulation` already has `metrics`, `robot`, `logger` members with all needed data post-run | We only need getters — no algorithmic change |
| `PerformanceMetrics::getCompletionPercent()` and `Robot::getTotalDistance()` exist and are `const` | Safe to call from `const` getters |
| `DataLogger::step_count` is private with **no getter** | Need to add `getSampleCount()` to `DataLogger` too |
| No automated unit-test framework exists | Integration test via headless batch run is the validation path |
| Build flags include `-Wall` | All new code must be warning-clean |

### 3. `plan.md` — 7-step checklist covering:
- Adding `getSampleCount()` to `DataLogger`
- Adding 4 getters to `Simulation`
- Wiring accumulators + averages in `BatchSimulation::runBatch()`
- Exact `0`-safe guard for division, naming conventions, and build verification

### 4. `run-tests.sh` — script that:
- Initialises git submodules
- Installs `libsdl2-dev` if missing
- Does a clean CMake configure + build with `-Wall -Werror`
- Runs `--batch 5 --headless` and parses `batch_summary.txt`
- Asserts all four averages are `> 0` with named PASS/FAIL output