All checklist items are implemented and committed. Here's a summary of what was done:

### Changes Made

1. **`include/DataLogger.h`** — Added `getSampleCount() const` inline getter next to `getFilepath()`, returning `step_count` (which is already maintained by `logSample()`).

2. **`include/Simulation.h`** — Added three public getter declarations: `getCompletionPercent()`, `getTotalDistance()`, and `getSampleCount()`, placed after the existing `getCurrentStep()` and `isComplete()` getters.

3. **`src/Simulation.cpp`** — Implemented the three getter methods: `getCompletionPercent()` delegates to `metrics->getCompletionPercent()`, `getTotalDistance()` delegates to `robot->getTotalDistance()`, and `getSampleCount()` delegates to `logger->getSampleCount()`.

4. **`src/BatchSimulation.cpp`** — Four accumulator variables (`sum_completion`, `sum_steps`, `sum_distance`, `sum_samples`) declared before the loop; inside `if (success)`, all four getters are called and accumulated; after the loop, averages are computed with a divide-by-zero guard (`if (results.successful_runs > 0)`), and `results.total_samples` is unconditionally assigned. The old placeholder comment was removed.