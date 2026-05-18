The commit is clean with real file changes across all 4 expected files. Here's a summary of what was implemented:

## Summary

All four checklist items from `plan.md` were implemented:

1. **`include/DataLogger.h`** — Added `int getSampleCount() const { return step_count; }` inline getter after `getFilepath()`. Exposes the existing `step_count` counter that `DataLogger` already tracks internally.

2. **`include/Simulation.h`** — Added four public getter declarations in the `public:` section:
   - `getCompletionPercent()` — declared only (defined in .cpp to avoid header coupling)
   - `getTotalSteps()` — inline, reads `current_step` directly
   - `getTotalDistance()` — declared only (defined in .cpp)
   - `getTotalSamples()` — declared only (defined in .cpp)

3. **`src/Simulation.cpp`** — Added three out-of-line getter definitions at the bottom, delegating to `metrics->getCompletionPercent()`, `robot->getTotalDistance()`, and `logger->getSampleCount()`.

4. **`src/BatchSimulation.cpp`** — Replaced the stub loop body with:
   - Four accumulator variables declared before the loop (`sum_completion`, `sum_steps`, `sum_distance`, `sum_samples`)
   - Accumulators updated inside the `if (success)` block only (to keep averages meaningful for successful runs)
   - Post-loop averaging with divide-by-zero guard using `results.successful_runs`
   - Removed the old "Would need to expose more metrics..." comment