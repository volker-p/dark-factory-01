# Implementation Plan: Populate Batch Simulation Statistics

## Goal

Add getter methods to `Simulation` that expose post-run metrics (completion %, steps, distance, samples logged), then wire `BatchSimulation::runBatch()` to accumulate those values and compute real averages in `BatchResults`.

---

## Files to Change

| File | What changes and why |
|---|---|
| `include/Simulation.h` | Add four `const` getter declarations: `getCompletionPercent()`, `getStepCount()`, `getTotalDistance()`, and `getSampleCount()`. These expose `metrics_`, `current_step`, `robot_`, and `logger_` post-run data without making any member public. |
| `src/Simulation.cpp` | Implement the four getters (some are trivial pass-throughs; `getSampleCount()` delegates to `logger_->getStepCount()`). Also change the private member names if needed to follow the `_` suffix convention for private members (per spec constraints). |
| `include/DataLogger.h` | Add a `getSampleCount() const` getter declaration that exposes `step_count_`. Rename `step_count` → `step_count_` per naming convention (private members use `_` suffix). |
| `src/DataLogger.cpp` | Rename `step_count` → `step_count_` wherever it appears, and implement `getSampleCount()`. |
| `src/BatchSimulation.cpp` | After each `sim.run()` / `sim.runHeadless()` call, read the four getters and accumulate totals. After the loop, divide by `successful_runs` (guarding division by zero) to populate `results.avg_completion_percent`, `results.avg_steps`, `results.avg_distance_cm`, and `results.total_samples`. Remove the placeholder comment. |

---

## Implementation Checklist

1. **`include/DataLogger.h`** — rename the private member `step_count` → `step_count_` (one occurrence in the declaration). Add the public getter:
   ```cpp
   int getSampleCount() const { return step_count_; }
   ```

2. **`src/DataLogger.cpp`** — replace every use of `step_count` with `step_count_` (three occurrences: constructor initialiser, increment in `logSample()`, print in `close()`).

3. **`include/Simulation.h`** — add four getter declarations to the `public:` section (after the existing `getCurrentStep()` and `isComplete()` getters):
   ```cpp
   double getCompletionPercent() const;
   double getTotalDistance() const;
   int    getSampleCount() const;
   ```
   Note: `getCurrentStep()` already exists and covers step count — it can be reused by `BatchSimulation`. No rename is required for the existing getter.

4. **`src/Simulation.cpp`** — implement the three new getters (placed after the existing inline definitions or at the bottom of the file):
   ```cpp
   double Simulation::getCompletionPercent() const { return metrics->getCompletionPercent(); }
   double Simulation::getTotalDistance()     const { return robot->getTotalDistance(); }
   int    Simulation::getSampleCount()       const { return logger->getSampleCount(); }
   ```
   These are safe to call only after `run()` / `runHeadless()` returns because `metrics`, `robot`, and `logger` are all valid `unique_ptr` members that are initialised before the simulation loop runs.

5. **`src/BatchSimulation.cpp`** — in `runBatch()`, declare accumulator variables before the loop:
   ```cpp
   double total_completion = 0.0;
   double total_steps      = 0.0;
   double total_distance   = 0.0;
   int    total_samples    = 0;
   ```
   After the `if (success) { results.successful_runs++; }` block, unconditionally (or only for successful runs — see Risks) add:
   ```cpp
   total_completion += sim.getCompletionPercent();
   total_steps      += sim.getCurrentStep();
   total_distance   += sim.getTotalDistance();
   total_samples    += sim.getSampleCount();
   ```
   After the loop, populate averages (guard against zero successful runs):
   ```cpp
   if (results.successful_runs > 0) {
       results.avg_completion_percent = total_completion / results.successful_runs;
       results.avg_steps              = total_steps      / results.successful_runs;
       results.avg_distance_cm        = total_distance   / results.successful_runs;
   }
   results.total_samples = total_samples;
   ```
   Remove the placeholder comment `// Note: Would need to expose more metrics...`.

6. **Build check** — compile with `cmake --build cmake-build-debug` and confirm zero `-Wall` warnings.

7. **Functional test** — run `./cmake-build-debug/SimulationPathFinder --headless --batch 5` and inspect the generated `batch_summary.txt`. Confirm all four average fields are non-zero.

---

## Test Strategy

### New tests to add
There are no existing automated unit tests in the repository (no `tests/` directory, no test target in `CMakeLists.txt`). The project's test strategy is functional: run the executable and inspect output/files.

**Functional test (manual / scripted):**
- Run `./cmake-build-debug/SimulationPathFinder --headless --batch 5 --output-dir ./test_output/`
- Assert exit code is `0`.
- Assert `test_output/batch_summary.txt` exists.
- Assert the summary file contains lines where the numeric values after `Average completion:`, `Average steps:`, `Average distance:`, and `Total training samples:` are all **> 0**.

Example shell assertions:
```bash
grep -E "Average completion: [1-9]" test_output/batch_summary.txt
grep -E "Average steps: [1-9]"      test_output/batch_summary.txt
grep -E "Average distance: [1-9]"   test_output/batch_summary.txt
grep -E "Total training samples: [1-9]" test_output/batch_summary.txt
```

### Existing behaviour not to break
- Single-run paths through `Simulation::run()` and `Simulation::runHeadless()` must still return `true` and write CSV files correctly.
- `DataLogger::close()` output line (logged sample count) must still print correctly — verified by renaming `step_count` → `step_count_` consistently.
- `BatchSimulation::saveSummary()` signature and output format are unchanged; only the values written will now be non-zero.

---

## Risks and Edge Cases

| Risk | Mitigation |
|---|---|
| **All runs fail** (`successful_runs == 0`): division by zero when computing averages | Guard with `if (results.successful_runs > 0)` before dividing; averages remain `0.0` (which is correct — there are no successful runs to average). `total_samples` is accumulated regardless and will still reflect logged data. |
| **Accumulating metrics for failed runs**: spec says averages are "for successful runs"; a run always returns `true` in the current code, but future code might not. | Accumulate inside `if (success) { ... }` block so only successful-run data enters the averages. |
| **`logger` is closed before getters are called**: `logger->close()` is called at the end of `Simulation::run()`, which flushes the file. `step_count_` is an in-memory `int` that is NOT reset by `close()`, so `getSampleCount()` will still return the correct value after the run. Verify this is the case in `DataLogger.cpp`. | Confirmed: `close()` only calls `file.close()` and prints; it does not reset `step_count_`. |
| **`robot` and `metrics` are `nullptr` before `run()` is called**: if `BatchSimulation` somehow calls a getter before running a sim, it will crash. | Getters are only called inside `BatchSimulation::runBatch()` immediately after a `sim.run()` / `sim.runHeadless()` call — `run()` initialises both `robot` and `metrics` before the loop. Safe. |
| **`step_count` rename**: if `step_count` is referenced in any other `.cpp` file (e.g. via a friend or macro), the rename will break it. | `step_count` is only accessed inside `DataLogger.cpp`; it is private and has no friend declarations. Only three occurrences to update. |
| **Naming convention for existing `Simulation` members**: the spec requires `_` suffix for private members. `current_step`, `elapsed_time_ms`, and `is_complete` in `Simulation` don't follow this convention, but they are pre-existing. The spec says to *follow* conventions when *adding* new code — do not rename existing members (scope creep, risk of missing an occurrence, and it would expand the diff unnecessarily). |
