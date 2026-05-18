# Implementation Plan: Populate Batch Simulation Statistics

## Goal

Expose `Simulation`'s final metrics (completion %, steps, distance, sample count) via getter methods, then have `BatchSimulation::runBatch()` accumulate and average them into `BatchResults`.

---

## Files to Change

| File | What Changes and Why |
|---|---|
| `include/Simulation.h` | Add three new getter method declarations: `getCompletionPercent()`, `getTotalSteps()`, `getTotalDistance()`, and `getTotalSamples()`. These are the four values `BatchSimulation` needs after each run completes. All read existing private members — no structural change needed. |
| `include/DataLogger.h` | Add a `getSampleCount()` const getter declaration that returns `step_count`. `DataLogger` already tracks `step_count` but never exposes it. |
| `src/DataLogger.cpp` | Add the inline or out-of-line definition for `getSampleCount()`. |
| `src/BatchSimulation.cpp` | Replace the stub loop body that only counts `successful_runs` with code that also reads the four new getters and accumulates running sums, then computes averages after the loop. |

---

## Implementation Checklist

1. **`include/DataLogger.h`** — Add a public getter after the existing `getFilepath()` getter:
   ```cpp
   int getSampleCount() const { return step_count; }
   ```
   This is safe as an inline definition in the header, consistent with the style of other headers in the project.

2. **`include/Simulation.h`** — Add four public getters inside the `public:` section, after the existing `isComplete()` getter:
   ```cpp
   double getCompletionPercent() const;
   int    getTotalSteps()        const { return current_step; }
   double getTotalDistance()     const;
   int    getTotalSamples()      const;
   ```
   - `getTotalSteps()` can be inline (reads `current_step` directly).
   - `getCompletionPercent()`, `getTotalDistance()`, and `getTotalSamples()` must delegate to the `metrics_` and `robot_` / `logger_` members which are `unique_ptr`s (non-null after `run()`), so defining them inline in the header would expose internal headers to `BatchSimulation` unnecessarily — define them in `src/Simulation.cpp` instead.

   **Note on naming convention:** The spec and `CLAUDE.md` say private members use a `_` suffix. The existing private members in `Simulation` (`current_step`, `elapsed_time_ms`, `is_complete`) do *not* use that suffix (inspect the header). Follow the existing code, not the stated convention for the new getters.

3. **`src/Simulation.cpp`** — Add three non-inline getter definitions at the bottom of the file (after `run()`):
   ```cpp
   double Simulation::getCompletionPercent() const {
       return metrics->getCompletionPercent();
   }

   double Simulation::getTotalDistance() const {
       return robot->getTotalDistance();
   }

   int Simulation::getTotalSamples() const {
       return logger->getSampleCount();
   }
   ```
   These delegate to `metrics`, `robot`, and `logger` respectively. All three are `unique_ptr` members guaranteed to be initialized before `run()` returns.

4. **`src/BatchSimulation.cpp`** — Rewrite the per-run accumulation block:
   - Declare four `double` accumulator variables before the loop (initialised to `0.0`):
     `sum_completion`, `sum_steps`, `sum_distance`, `sum_samples` (the last as `int` → promote to `double` for averaging, or keep as `int` for `total_samples`).
   - After each `sim.runHeadless()` / `sim.run()` call, regardless of success, read the four getters and add them to the accumulators (the spec says "averages across all runs"; only accumulate on `success` if zeros are unwanted for failed runs — choose to accumulate only successful runs to keep averages meaningful).
   - After the loop, compute averages using `results.successful_runs` as the denominator (guard against divide-by-zero):
     ```cpp
     if (results.successful_runs > 0) {
         results.avg_completion_percent = sum_completion / results.successful_runs;
         results.avg_steps              = sum_steps      / results.successful_runs;
         results.avg_distance_cm        = sum_distance   / results.successful_runs;
     }
     results.total_samples = static_cast<int>(sum_samples);
     ```
   - Remove (or replace) the comment: `// Note: Would need to expose more metrics...`

5. **Verify zero `-Wall` warnings:** The build flags in `CMakeLists.txt` already include `-Wall`. After changes, build with `cmake --build cmake-build-debug` and check for any new warnings, especially about unused variables or shadowed names.

---

## Test Strategy

### Functional / acceptance test (manual / script)

The repo has no unit-test framework (no GTest, CTest, or equivalent is present). The test approach mirrors what `test.sh` and `run_test.sh` already do — run the binary headless and inspect output.

**Primary test:** Run a batch of 5 simulations headless and check `batch_summary.txt`:
```bash
./cmake-build-debug/SimulationPathFinder --headless --batch 5 --output-dir ./test_output/
cat ./test_output/batch_summary.txt
```
Assert:
- Exit code is `0`.
- `batch_summary.txt` exists.
- `avg_completion_percent` > 0.
- `avg_steps` > 0.
- `avg_distance_cm` > 0.
- `total_samples` > 0.

**Secondary test:** Verify that `saveSummary()` correctly outputs the populated values (already covered by reading the file above — `saveSummary()` is called in `main.cpp` after `runBatch()` returns).

### Existing tests to verify

- `test.sh` and `run_test.sh` both run `--batch 2 --headless` and should continue to pass after the change. The change is strictly additive (new getters, new accumulation logic); no existing interfaces are modified.

### Edge cases in test

- **Batch size = 1:** Verify averages equal the single run's values (no division error).
- **All runs fail:** If `successful_runs = 0`, the divide-by-zero guard keeps averages at `0.0` and `total_samples` is whatever was accumulated.

---

## Risks and Edge Cases

| Risk | Detail | Mitigation |
|---|---|---|
| `logger` is closed before getters are called | `logger->close()` is called at the end of `Simulation::run()`, which zeroes the file handle but `step_count` is a plain `int` that is not reset on close. `getSampleCount()` will still return the correct value. | Confirm by reading `DataLogger::close()` — it only closes the `ofstream`, not the counter. |
| `robot` / `metrics` pointer validity | Both are `unique_ptr` members of `Simulation`. They are created in the constructor and never reset during a run. By the time `BatchSimulation` calls the getters, `run()` has returned but the `Simulation` object is still in scope on the stack inside the loop body. Safe. | No extra work needed. |
| Accumulating failed-run metrics | A failed `run()` returns `false` but still populates `metrics`, `robot`, and `logger` with whatever state was reached before failure. Accumulating them would skew averages. | Only accumulate inside `if (success)` block. |
| `total_samples` type mismatch | `BatchResults::total_samples` is `int`; the accumulator can overflow for very large batches at 10 000 steps each. At the default 10 000 steps × 100 runs = 1 000 000 samples, well within `int` range. | No change needed. |
| `avg_steps` type | `BatchResults::avg_steps` is `double`. `current_step` is `int`. The division will upcast automatically; no truncation risk. | No change needed. |
| `-Wall` warnings from new code | Using an `int` accumulator summed into a `double` result could trigger sign-conversion or narrowing warnings depending on GCC version. | Cast explicitly: `static_cast<double>(sim.getTotalSteps())` in the accumulation line. |
