The commit is recorded successfully. Here's a summary of what was implemented:

## Summary of Changes

All three checklist items from `plan.md` were implemented:

### 1. `include/DataLogger.h`
Added `getSampleCount() const` getter that returns the private `step_count` member, correctly reflecting the number of training samples logged.

### 2. `include/Simulation.h`
Added four new public getter methods to the `// Getters` block:
- `getCompletionPercent()` — delegates to `metrics->getCompletionPercent()`
- `getTotalSteps()` — returns `current_step`
- `getTotalDistance()` — delegates to `robot->getTotalDistance()`
- `getSampleCount()` — delegates to `logger->getSampleCount()`

### 3. `src/BatchSimulation.cpp`
- Added four accumulator variables (`sum_completion`, `sum_steps`, `sum_distance`, `sum_samples`) before the loop.
- Inside the loop, replaced the stale comment block with calls to the new getters — successful runs accumulate the three averages, and all runs contribute to `sum_samples`.
- After the loop, computes and stores averages guarded by `successful_runs > 0` to avoid division by zero, then assigns `total_samples`.

The `saveSummary()` function already writes all four populated fields — no changes needed there (checklist item 4 confirmed).