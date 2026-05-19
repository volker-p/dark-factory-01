Goal: Implement the spec at specs/simulation-path-finder/config-and-debug.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 43.6k tokens in / 6.9k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: failed
- **test**: succeeded
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    (54 lines omitted)
    === Running simulation 3/5 ===
    Robot stuck, terminating simulation.
    Logged 1382 samples to ./data/training_data_2026-05-19_08-43-32_run3.csv
    Simulation complete: 1% explored, 1382 steps, 228.592 cm traveled
    
    === Running simulation 4/5 ===
    Robot stuck, terminating simulation.
    Logged 798 samples to ./data/training_data_2026-05-19_08-43-32_run4.csv
    Simulation complete: 1% explored, 798 steps, 138.576 cm traveled
    
    === Running simulation 5/5 ===
    Robot stuck, terminating simulation.
    Logged 2615 samples to ./data/training_data_2026-05-19_08-43-32_run5.csv
    Simulation complete: 1% explored, 2615 steps, 423.376 cm traveled
    
    === Batch complete: 5/5 successful ===
    
    === Final Results ===
    Total time: 0.0666112 seconds
    Successful runs: 5/5
    Summary saved to ./data/batch_summary.txt
    
    Training data generated successfully!
    Check ./data/ for CSV files.
    --- TESTS PASSED ---
    ```
- **test_gate**: succeeded
- **review**: succeeded
  - Model: claude-opus-4-7, 41.6k tokens in / 10.1k out
  - Files: /workspace/dark-factory-01/review-report.md
- **gate_pr**: succeeded
- **implement**: failed
- **test**: succeeded
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    (54 lines omitted)
    === Running simulation 3/5 ===
    Robot stuck, terminating simulation.
    Logged 1382 samples to ./data/training_data_2026-05-19_08-43-32_run3.csv
    Simulation complete: 1% explored, 1382 steps, 228.592 cm traveled
    
    === Running simulation 4/5 ===
    Robot stuck, terminating simulation.
    Logged 798 samples to ./data/training_data_2026-05-19_08-43-32_run4.csv
    Simulation complete: 1% explored, 798 steps, 138.576 cm traveled
    
    === Running simulation 5/5 ===
    Robot stuck, terminating simulation.
    Logged 2615 samples to ./data/training_data_2026-05-19_08-43-32_run5.csv
    Simulation complete: 1% explored, 2615 steps, 423.376 cm traveled
    
    === Batch complete: 5/5 successful ===
    
    === Final Results ===
    Total time: 0.0666112 seconds
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
- human.gate.gate_pr.answer: R
- human.gate.gate_pr.label: [R] Rework
- human.gate.gate_pr.question: Approve PR
- human.gate.label: [R] Rework
- human.gate.selected: R


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