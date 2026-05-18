All changes are staged. Here's a summary of everything implemented:

## Changes Made

### `include/DataLogger.h`
- Added `int getSampleCount() const { return step_count; }` inline getter in the `public:` section, exposing the private `step_count` field without making it public.

### `include/Simulation.h`
- Added four `const` inline getter methods in the `// Getters` section:
  - `getFinalCompletionPercent()` → delegates to `metrics->getCompletionPercent()`
  - `getFinalSteps()` → returns `current_step`
  - `getFinalDistanceCm()` → delegates to `robot->getTotalDistance()`
  - `getFinalSampleCount()` → delegates to `logger->getSampleCount()`

### `src/BatchSimulation.cpp`
- Declared four accumulator variables (`sum_completion`, `sum_steps`, `sum_distance`, `sum_samples`) before the simulation loop.
- Inside the existing `if (success)` block, accumulate all four metrics via the new getters after each successful run.
- After the loop, compute true averages guarded by `if (results.successful_runs > 0)` to prevent division by zero, and assign `results.total_samples = sum_samples` unconditionally.
- Removed the `// Note: Would need to expose more metrics...` placeholder comment.