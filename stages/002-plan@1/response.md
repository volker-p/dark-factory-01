Both files are in place. Here's a summary of everything produced:

---

## What was done

### 1. Spec analysis (`specs/simulation-path-finder/batch-statistics.md`)
- **`target_repo`**: `volker-p/SimulationPathFinder`
- **`type`**: `feature`
- **Core problem**: `BatchSimulation::runBatch()` never reads post-run metrics from `Simulation`; all four average fields in `BatchResults` stay at 0.
- **Constraint**: add getters to `Simulation` only — no public members, no struct/signature changes, no changes to the maze algorithm.

### 2. Repository reading
Cloned the repo and read `CLAUDE.md`, all six affected source/header files (`Simulation.h/.cpp`, `DataLogger.h/.cpp`, `BatchSimulation.h/.cpp`, `PerformanceMetrics.h`), and the build/test scripts. This revealed:
- `Simulation` already has `metrics` (→ `getCompletionPercent()`), `robot` (→ `getTotalDistance()`), `current_step`, and `logger` (→ `step_count` via `DataLogger`)
- `DataLogger::step_count` is private with no getter yet
- `BatchSimulation` has the comment flagging the exact gap to fix

### 3. `plan.md` — 5 files to touch, 8 numbered steps, full risk table

### 4. `run-tests.sh` — installs `cmake build-essential git libsdl2-dev`, initialises the `nlohmann/json` submodule, does a clean CMake configure + build, runs `--headless --batch 5`, then asserts all four summary fields are non-zero.