Both files are ready. Here's a summary of what was produced:

---

## What was done

### 1. Read & analysed the spec
- **Target repo**: `volker-p/SimulationPathFinder`
- **Type**: feature
- **Core problem**: `BatchSimulation::runBatch()` runs simulations but never reads any result metrics back from `Simulation`, leaving `BatchResults` full of zeros.

### 2. Explored the target repository
Key findings from reading all relevant source files:
- `Simulation` already has `metrics` (`PerformanceMetrics`), `robot` (`Robot`), and `logger` (`DataLogger`) as private `unique_ptr` members — all fully populated after `run()` returns.
- `DataLogger` tracks `step_count` (logged samples) but has no getter.
- `Simulation` exposes only `getCurrentStep()` and `isComplete()` — no metrics, distance, or sample-count getters.
- `BatchSimulation::runBatch()` has an explicit TODO comment: *"Would need to expose more metrics from Simulation to calculate averages"*.

### 3. `plan.md` — Implementation plan
Five files to change, in a clear dependency order:
1. **`include/DataLogger.h`** — rename `step_count` → `step_count_`; add `getSampleCount()` getter.
2. **`src/DataLogger.cpp`** — rename `step_count` → `step_count_` (3 occurrences).
3. **`include/Simulation.h`** — declare `getCompletionPercent()`, `getTotalDistance()`, `getSampleCount()`.
4. **`src/Simulation.cpp`** — implement those three getters as delegation to sub-objects.
5. **`src/BatchSimulation.cpp`** — accumulate the four metrics per run, compute averages after the loop, populate `BatchResults`.

### 4. `run-tests.sh` — Build & test script
- Installs `cmake`, `build-essential`, `git`, `libsdl2-dev` if absent.
- Fetches the `nlohmann/json` submodule.
- Configures and builds with CMake.
- Runs `--headless --batch 5` and asserts all four average fields in `batch_summary.txt` are non-zero.