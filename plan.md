# Implementation Plan: Populate Batch Simulation Statistics

## Goal
Add getter methods to `Simulation` for completion percent, step count, distance, and
training sample count, then use them in `BatchSimulation::runBatch()` to fill in
`BatchResults` with real averages instead of zeros.

---

## Files to Change

| File | What changes and why |
|---|---|
| `include/Simulation.h` | Add three new public getter declarations: `getCompletionPercent()`, `getTotalSteps()`, and `getTotalDistance()`. `DataLogger` already counts samples internally; add `getSampleCount()` too. These expose the post-run data that `BatchSimulation` needs, without making any members public. |
| `include/DataLogger.h` | Add a public `getSampleCount()` getter declaration so `Simulation` can forward the value to callers. `step_count` is already maintained in `DataLogger`; it just needs to be readable. |
| `src/DataLogger.cpp` | Implement `getSampleCount()` — one-liner returning `step_count`. |
| `src/Simulation.cpp` | Implement the three new getter methods on `Simulation`: `getCompletionPercent()` delegates to `metrics->getCompletionPercent()`; `getTotalSteps()` returns `current_step`; `getTotalDistance()` delegates to `robot->getTotalDistance()`; `getSampleCount()` delegates to `logger->getSampleCount()`. |
| `src/BatchSimulation.cpp` | After each `sim.run()` / `sim.runHeadless()` call, read the four getters and accumulate sums. After the loop, divide by the number of successful runs (guard against divide-by-zero) to compute averages and assign them to `results`. Remove the "Would need to expose more metrics" comment. |

---

## Implementation Checklist

1. **`include/DataLogger.h`** — Add `getSampleCount()` getter in the public section:
   ```cpp
   int getSampleCount() const { return step_count; }
   ```
   Place it next to the existing `getFilepath()` getter.

2. **`include/Simulation.h`** — Add four public getter declarations after the existing
   `getCurrentStep()` and `isComplete()` getters:
   ```cpp
   double getCompletionPercent() const;
   double getTotalDistance() const;
   int    getSampleCount() const;
   ```
   (`getCurrentStep()` is already present and returns `current_step`, which equals total
   steps taken — no new getter needed for steps; `BatchSimulation` can call `getCurrentStep()`.)

3. **`src/Simulation.cpp`** — Add the three getter implementations outside the class
   definition (below the `run()` function, or in a small "Getters" block):
   ```cpp
   double Simulation::getCompletionPercent() const {
       return metrics->getCompletionPercent();
   }

   double Simulation::getTotalDistance() const {
       return robot->getTotalDistance();
   }

   int Simulation::getSampleCount() const {
       return logger->getSampleCount();
   }
   ```
   Note: `metrics` and `robot` are `unique_ptr` members; they are valid after `run()`
   returns because they live for the full lifetime of the `Simulation` object.

4. **`src/BatchSimulation.cpp`** — Declare accumulator variables before the simulation
   loop:
   ```cpp
   double sum_completion = 0.0;
   double sum_steps      = 0.0;
   double sum_distance   = 0.0;
   int    sum_samples    = 0;
   ```

5. **`src/BatchSimulation.cpp`** — Inside the loop, after the `if (success)` block,
   read the four getters from `sim` and add to the accumulators for **all** runs
   (not just successful ones — this mirrors what the existing `saveSummary()` prints,
   but accumulate only successful-run values to keep the "average for successful runs"
   semantics that makes the summary meaningful):
   ```cpp
   if (success) {
       results.successful_runs++;
       sum_completion += sim.getCompletionPercent();
       sum_steps      += sim.getCurrentStep();
       sum_distance   += sim.getTotalDistance();
       sum_samples    += sim.getSampleCount();
   }
   ```
   Remove the old comment `// Note: Would need to expose more metrics…`.

6. **`src/BatchSimulation.cpp`** — After the loop (before the renderer cleanup), assign
   the averages to `results`, guarding against zero successful runs:
   ```cpp
   if (results.successful_runs > 0) {
       results.avg_completion_percent = sum_completion / results.successful_runs;
       results.avg_steps              = sum_steps      / results.successful_runs;
       results.avg_distance_cm        = sum_distance   / results.successful_runs;
   }
   results.total_samples = sum_samples;
   ```

7. **Build check** — Rebuild with `cmake -B cmake-build-debug -S . && cmake --build cmake-build-debug`
   and confirm zero `-Wall` warnings.

8. **Smoke test** — Run `./cmake-build-debug/SimulationPathFinder --headless --batch 5`
   and inspect `data/batch_summary.txt`. All four average fields must be non-zero.

---

## Test Strategy

### New tests to add
There are no existing unit-test files in this repository (no `tests/` directory, no
Google Test / Catch2 setup). The project is validated by running the binary directly.

Add the following checks to a new `run-tests.sh` (or extend the existing smoke-test):

1. **Build succeeds with zero warnings** — pipe `cmake --build` stderr through `grep -c 'warning:'`
   and assert count is 0.

2. **Headless batch exit code** — `./cmake-build-debug/SimulationPathFinder --headless --batch 5`
   must exit 0.

3. **Summary file exists and is non-trivial** — After the run:
   - `data/batch_summary.txt` must exist.
   - `grep "Average completion:" data/batch_summary.txt` must show a value `> 0`.
   - `grep "Average steps:" data/batch_summary.txt` must show a value `> 0`.
   - `grep "Average distance:" data/batch_summary.txt` must show a value `> 0`.
   - `grep "Total training samples:" data/batch_summary.txt` must show a value `> 0`.

### Existing behaviour to verify is unchanged
- The `successful_runs` / `total_runs` counts are still incremented correctly (always
  were, we don't touch that logic).
- `saveSummary()` signature and output format remain unchanged (we only populate the
  struct fields it already writes).
- Individual per-run CSV files are still created (we don't touch `DataLogger::open()` /
  `close()` / `logSample()`).

---

## Risks and Edge Cases

| Risk | Mitigation |
|---|---|
| **All runs fail** (`successful_runs == 0`) | Guard the average computation with `if (results.successful_runs > 0)` to avoid division by zero; averages remain 0.0, which is honest for an all-failure batch. |
| **`metrics` or `robot` are null after `run()` returns early** | `run()` currently always returns `true` (never `false` after the logger opens); if it returned early before `initializeRobot()`, `robot` would be null. However, in the only early-return path (`logger->open()` failing), `success` is `false`, so we only call getters inside `if (success)` — safe. |
| **`logger->getSampleCount()` after `logger->close()`** | `close()` only closes the file; `step_count` is not reset. Calling `getSampleCount()` after `close()` is correct. |
| **Accumulating only successful runs skews averages** | The spec says "averages across all runs"; if a run fails mid-way the data is partial. Accumulating only successful runs is safer and more useful for the training data consumer. If the spec intent is total-run averaging, the divisor must change to `results.total_runs`. Given spec wording "all averages > 0 for successful runs", accumulating successful-only is the right interpretation. |
| **`current_step` vs actual steps logged** | `current_step` increments at the end of each loop iteration after `logSample()` — they are always equal when the loop exits. Using `getCurrentStep()` is correct. |
| **Thread safety** | `BatchSimulation` runs simulations sequentially (single-threaded loop). No concurrency concern. |
