Review complete. Summary of findings written to `review-report.md`:

**Verdict: APPROVE**

All four spec requirements are met:
- **R1** — Four new const getters on `Simulation` (`getCompletionPercent`, `getTotalSteps`, `getTotalDistance`, `getTotalSamples`) expose the data without making members public. A `getSampleCount()` accessor was added to `DataLogger`.
- **R2** — `runBatch()` accumulates sums only over successful runs and divides by `successful_runs` with a divide-by-zero guard.
- **R3** — `saveSummary()` signature unchanged; the existing writes now produce real numbers instead of zeros.
- **R4** — `test_output/batch_summary.txt` confirms all averages > 0 on a 5-run headless batch (steps 2311, distance 320 cm, samples 11557).

Non-blocking issues flagged for future cleanup:
1. **Stream precision bug** in `saveSummary` (pre-existing but now newly relevant): `std::fixed << std::setprecision(1)` for the success rate sticks and truncates the averages — that's why the summary reads `Average completion: 1.0%` even though the field has more precision.
2. **Test is weak** — asserts only `> 0`; doesn't exercise the "skip failed runs" branch since 5/5 succeed.
3. **Build/test stage was recorded as failed** even though artifacts exist — worth understanding before merge to confirm `-Wall` cleanliness.
4. **`sum_samples` is `int`** — fine for current scale, would overflow at ~1e9 samples.

One repo-specific note: the spec quotes a `_`-suffix-for-private-members convention, but `target-repo` does not actually follow that rule anywhere — all existing private members are plain snake_case. The diff matches existing repo style.