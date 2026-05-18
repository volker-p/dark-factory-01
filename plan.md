# Implementation Plan: Populate Batch Simulation Statistics

## Goal

Add getter methods to `Simulation` that expose post-run metrics (`completion %`, `steps`, `distance`, `sample count`), then wire those into `BatchSimulation::runBatch()` so `BatchResults` is populated with real averages rather than zeros.

---

## Files to Change

| File | What Changes and Why |
|------|----------------------|
| `include/Simulation.h` | Add four `const` getter methods: `getFinalCompletionPercent()`, `getFinalSteps()`, `getFinalDistanceCm()`, `getFinalSampleCount()`. These expose post-run state from `metrics_`, `current_step`, `robot_`, and `logger_` without making any member public. |
| `src/BatchSimulation.cpp` | After each `sim.run()`/`sim.runHeadless()` call, read the four new getters and accumulate running sums. After the loop, divide sums by the count of successful runs to produce true averages and write them into the `BatchResults` struct. Remove the "would need to expose metrics" comment. |

No other files need to change. `BatchResults` struct fields and `saveSummary()` signature are left untouched (per constraints). `common/maze_explorer.c` is not present in this repo and is not touched.

---

## Implementation Checklist

1. **Read `include/Simulation.h`** – confirm the private members available post-run:
   - `metrics_` (a `std::unique_ptr<PerformanceMetrics>`) → `getCompletionPercent()`
   - `current_step` (int) → number of steps taken
   - `robot_` (a `std::unique_ptr<Robot>`) → `getTotalDistance()`
   - `logger_` (a `std::unique_ptr<DataLogger>`) → `step_count` field (private) — see step 2

2. **Check `DataLogger` exposure** – `DataLogger::step_count` is private and has no getter.  
   Add a `getSampleCount() const` getter to `DataLogger` that returns `step_count`.  
   - Edit `include/DataLogger.h`: add `int getSampleCount() const { return step_count; }` inside the `public:` section.  
   - No `.cpp` change needed (inline getter).

3. **Add getters to `Simulation`** – edit `include/Simulation.h`, in the `// Getters` section after `isComplete()`:
   ```cpp
   double getFinalCompletionPercent() const { return metrics_->getCompletionPercent(); }
   int    getFinalSteps()             const { return current_step; }
   double getFinalDistanceCm()        const { return robot_->getTotalDistance(); }
   int    getFinalSampleCount()       const { return logger_->getSampleCount(); }
   ```
   All four are `const` inline one-liners — no `.cpp` change needed.

   > **Note on member names**: The header confirms: `metrics`, `robot`, `logger`, `current_step` — no trailing `_` suffix. Use these exact names in the getter bodies.

4. **Wire accumulators into `BatchSimulation::runBatch()`** – edit `src/BatchSimulation.cpp`:

   a. Before the simulation loop, declare four accumulator variables:
      ```cpp
      double sum_completion = 0.0;
      double sum_steps      = 0.0;
      double sum_distance   = 0.0;
      int    sum_samples    = 0;
      ```

   b. Inside the loop, after `if (success) { results.successful_runs++; }`, add:
      ```cpp
      if (success) {
          sum_completion += sim.getFinalCompletionPercent();
          sum_steps      += sim.getFinalSteps();
          sum_distance   += sim.getFinalDistanceCm();
          sum_samples    += sim.getFinalSampleCount();
      }
      ```
      *(The outer `if (success)` block already exists; merge these lines into it or add a second `if (success)` block immediately after — either is fine, but avoid duplication.)*

   c. After the loop (before the `if (renderer)` cleanup block), populate averages:
      ```cpp
      if (results.successful_runs > 0) {
          results.avg_completion_percent = sum_completion / results.successful_runs;
          results.avg_steps              = sum_steps      / results.successful_runs;
          results.avg_distance_cm        = sum_distance   / results.successful_runs;
      }
      results.total_samples = sum_samples;
      ```

   d. Remove the comment:
      ```
      // Note: Would need to expose more metrics from Simulation to calculate averages
      // For now, just count successful runs
      ```

5. **Verify naming conventions** – double-check every new identifier before saving:
   - Classes: `PascalCase` ✓ (no new classes)
   - Members: `snake_case` ✓ (`sum_completion`, `sum_steps`, etc.)
   - Private members use `_` suffix — new locals are not members, so no suffix needed
   - Getters follow the existing pattern (`getXxx() const`)

6. **Build with `-Wall` and fix any warnings** – run the build (see `run-tests.sh`). Common pitfalls:
   - Calling a non-`const` method through a `const`-qualified getter → ensure `getCompletionPercent()`, `getTotalDistance()`, `getSampleCount()` are all declared `const` (they already are or will be after step 2).
   - Implicit narrowing: `sum_steps / results.successful_runs` returns `double` and `avg_steps` is `double` — no issue.

7. **Run the headless batch test** (see `run-tests.sh`) and verify:
   - Exit code 0
   - `batch_summary.txt` contains non-zero values for all four averages

---

## Test Strategy

### Existing tests
There are no automated unit-test files (no `tests/` directory, no Google Test / Catch2 setup found). The repo's validation is done via the shell scripts `test.sh` and `verify_fix.sh`. These are integration tests that build and run the binary.

### Tests to add / run
1. **Build verification** – the CMake build must succeed with zero `-Wall` warnings.

2. **Headless batch integration test** – run:
   ```
   ./cmake-build-debug/SimulationPathFinder --batch 5 --headless --output-dir /tmp/spf_test/
   ```
   Then parse `/tmp/spf_test/batch_summary.txt` and assert:
   - `Average completion:` value is `> 0.0`
   - `Average steps:` value is `> 0`
   - `Average distance:` value is `> 0.0`
   - `Total training samples:` value is `> 0`

3. **Existing `test.sh` script** – runs `--batch 2 --headless`; should still pass after the change (it only checks exit code implicitly via `set -e`).

### Affected existing behaviour
- `saveSummary()` already writes all four fields; after this change the values will be non-zero, which is the desired behaviour.
- No behavioural change to `Simulation::run()` / `runHeadless()` — we only add read-only getters.

---

## Risks and Edge Cases

| Risk | Mitigation |
|------|-----------|
| **All runs fail** (`successful_runs == 0`) — division by zero for averages | Guard with `if (results.successful_runs > 0)` before dividing (step 4c). `total_samples` is accumulated unconditionally so it reflects all logged data. |
| **`logger_` is `nullptr` after `run()` fails early** | `Simulation::run()` returns `false` if `logger->open()` fails, before any samples are logged. Only accumulate metrics when `success == true`, so `logger_` will always have been opened and closed successfully. |
| **`robot_` or `metrics_` are `nullptr`** | Both are initialized in the `Simulation` constructor (before `run()` is called) and are never reset to `nullptr`. The getters are safe to call any time after construction. |
| **`DataLogger::step_count` is reset on `open()`** — if a `Simulation` is reused | `BatchSimulation` creates a fresh `Simulation` object per loop iteration (`Simulation sim(config)`) so there is no reuse problem. |
| **Naming mismatch** — actual member names may differ from what's written in comments | Always re-read the header before editing. The checklist notes to verify names from the actual file (step 3 note). |
| **Integer vs double for `avg_steps`** | `BatchResults::avg_steps` is declared `double` and `current_step` is `int`. The sum and division are all `double` arithmetic — no truncation. |
| **Zero `total_runs`** (`batch_size == 0`) — `saveSummary()` divides by `total_runs` for success rate | Pre-existing issue in `saveSummary()`; not introduced by this change and out of scope. |