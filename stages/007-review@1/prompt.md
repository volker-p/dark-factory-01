Goal: Implement the spec at specs/simulation-path-finder/config-and-debug.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 43.6k tokens in / 6.9k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 60.9k tokens in / 18.3k out
  - Files: /workspace/dark-factory-01/target-repo/config.json, /workspace/dark-factory-01/target-repo/include/BatchSimulation.h, /workspace/dark-factory-01/target-repo/include/Config.h, /workspace/dark-factory-01/target-repo/include/Maze.h, /workspace/dark-factory-01/target-repo/include/ScenarioSimulation.h, /workspace/dark-factory-01/target-repo/include/Simulation.h, /workspace/dark-factory-01/target-repo/include/WallFollower.h, /workspace/dark-factory-01/target-repo/main.cpp, /workspace/dark-factory-01/target-repo/src/BatchSimulation.cpp, /workspace/dark-factory-01/target-repo/src/Config.cpp, /workspace/dark-factory-01/target-repo/src/ScenarioSimulation.cpp, /workspace/dark-factory-01/target-repo/src/Simulation.cpp, /workspace/dark-factory-01/target-repo/src/WallFollower.cpp
- **test**: succeeded
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    (677 lines omitted)
    === Running simulation 3/5 ===
    Robot stuck, terminating simulation.
    Logged 1556 samples to ./data/training_data_2026-05-19_08-37-26_run3.csv
    Simulation complete: 1% explored, 1556 steps, 249.936 cm traveled
    
    === Running simulation 4/5 ===
    Robot stuck, terminating simulation.
    Logged 1341 samples to ./data/training_data_2026-05-19_08-37-26_run4.csv
    Simulation complete: 1% explored, 1341 steps, 235.424 cm traveled
    
    === Running simulation 5/5 ===
    Robot stuck, terminating simulation.
    Logged 1535 samples to ./data/training_data_2026-05-19_08-37-26_run5.csv
    Simulation complete: 1% explored, 1535 steps, 241.04 cm traveled
    
    === Batch complete: 5/5 successful ===
    
    === Final Results ===
    Total time: 0.0731625 seconds
    Successful runs: 5/5
    Summary saved to ./data/batch_summary.txt
    
    Training data generated successfully!
    Check ./data/ for CSV files.
    --- TESTS PASSED ---
    ```
- **test_gate**: succeeded

## Context
- human.gate.gate_plan.answer: A
- human.gate.gate_plan.label: [A] Approve
- human.gate.gate_plan.question: Approve Plan
- human.gate.label: [A] Approve
- human.gate.selected: A


You are an independent senior engineer reviewing a pull request. You did not write this code.

## Steps

1. Read the spec at `specs/simulation-path-finder/config-and-debug.md` — this is the acceptance criteria.
2. Get the full diff:
   ```bash
   cd target-repo && git diff origin/master..HEAD
   ```
3. Read `target-repo/AGENTS.md` to understand the project conventions.
4. Read `test-output.txt` — the full output from the test run.

## Write a satisfaction report to `review-report.md`

Structure it as follows:

### Test Results
- Did the test suite pass or fail?
- Paste the final build and test summary lines from `test-output.txt` (last 30 lines or the relevant summary section).
- Call out any warnings, errors, or unexpected output.

### Requirements
For each requirement in the spec, mark it as one of: ✅ Met / ⚠️ Partial / ❌ Missing.
Cite the specific file and line that satisfies it (or explain what is missing).

### Test Coverage
- Are new code paths covered by tests?
- Are edge cases from the spec tested?
- Any tests that are too weak to be meaningful?

### Code Quality
- Does the implementation follow the conventions in AGENTS.md?
- Any correctness issues, security concerns, or obvious bugs?
- Anything surprising that a human reviewer should look at?

### Verdict
End with one of:
- **APPROVE** — all P0 requirements met, no blocking issues
- **REQUEST CHANGES** — list specific blocking items that must be fixed before merge

Be specific. Reference file names and line numbers throughout.