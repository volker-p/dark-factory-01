Review report written to `/workspace/dark-factory-01/review-report.md`.

**Summary:**

- **Verdict: APPROVE** — all P0 requirements (R1–R5) are met, all 11 verification assertions pass, no blocking issues.

- **Key findings:**
  - R1–R5 each map to specific files and lines that satisfy them; the implementation closely follows the spec's prescribed shape (struct fields, signatures, header format).
  - Verified one trace row by hand — internally consistent.
  - `--trace` silent no-op without `--scenario`/`--scenario-suite` is correctly implemented.

- **Non-blocking observations called out:**
  - Pre-existing `-Wunused-parameter` warnings in `Renderer.cpp` (untouched file, present on master).
  - All five scenarios fail with ~9960 collisions — a pre-existing wall-follower regression from commit `cb10d47`, NOT introduced by this PR. The trace tooling being added here is the right next step to diagnose it.
  - Minor: missing trailing newlines in `Config.h`/`Config.cpp`, redundant loop counter `i` in `runScenario`, `static_cast<int>` instead of `std::floor` for cell coords (identical for non-negative positions), two different PI constants across two files.
  - Test coverage gaps: no assertion that `step` resets across scenarios in suite mode, no test of custom `wall_scan_angles_deg`, no precision assertions.