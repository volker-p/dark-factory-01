Review report written to `/workspace/dark-factory-01/review-report.md`.

## Summary

**Verdict: APPROVE**

The PR cleanly satisfies all four spec requirements:
- **R1 (expose metrics):** Four new const getters added to `Simulation` (lines 43–46) and one to `DataLogger` (line 38), all delegating to existing private state.
- **R2 (averages populated):** `BatchSimulation::runBatch()` now accumulates and divides correctly, with a divide-by-zero guard.
- **R3 (`saveSummary` writes them):** Signature unchanged; previously-printed-but-empty fields now contain real data.
- **R4 (`--headless --batch 5` exits 0 with non-zero averages):** Empirically verified — `test_output/batch_summary.txt` shows `Average steps: 2255.4`, `Average distance: 321.5 cm`, `Total training samples: 11277`.

All constraints respected: no public members, no struct/signature changes, no touches to `maze_explorer.c`, no `-Wall` warnings. The implementation is exactly as small as the problem requires (~17 net lines).

Non-blocking nits only:
1. Missing trailing newline in `src/BatchSimulation.cpp`.
2. Column-aligned spacing in the new getters in `Simulation.h` doesn't match the single-space style of the two existing getters in the same block.
3. The "samples count all runs, averages count successful runs only" semantic is in the plan but not commented in the code.

One observation worth flagging to a human: the spec references conventions in `AGENTS.md`, but the target repo only has `CLAUDE.md`. The `_` private-member-suffix convention mentioned in the spec isn't actually followed by any existing code in the repo, so the new code conforms to the *de facto* style.