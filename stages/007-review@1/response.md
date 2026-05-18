I've written the review report to `review-report.md`. Summary of findings:

**Verdict: APPROVE**

All four spec requirements (R1–R4) are met:
- **R1**: Four `Simulation` getters added (`getCompletionPercent`, `getCurrentStep` already existed, `getTotalDistance`, `getSampleCount`) — all `const`, no members made public.
- **R2**: `runBatch()` accumulates per successful run and divides by `successful_runs` with a div-by-zero guard (`src/BatchSimulation.cpp:29-63`).
- **R3**: `saveSummary()` writes the four populated fields (`src/BatchSimulation.cpp:89-92`); signature unchanged.
- **R4**: The headless 5-run batch produced `Average completion: 1.0%`, `Average steps: 2089.0`, `Average distance: 293.3 cm`, `Total training samples: 10445` — all > 0.

**Constraints all respected** (`BatchResults` struct intact, no `common/maze_explorer.c` change, `step_count` correctly renamed with `_` suffix).

**Non-blocking nits noted**:
1. `src/DataLogger.cpp` lost its trailing newline (`\ No newline at end of file`).
2. `step_count → step_count_` rename is a drive-by style fix outside the strict spec scope.
3. The 1% completion is pre-existing wall-follower behaviour, not a regression.
4. Test only asserts `> 0`, not magnitudes — adequate for catching the original bug but won't catch absurd values.