Goal: Implement the spec at specs/simulation-path-finder/sensor-config-and-tracing.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 38.3k tokens in / 10.2k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 7.0k tokens in / 892 out
- **test**: succeeded
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    -- Configuring done (0.0s)
    -- Generating done (0.0s)
    -- Build files have been written to: /repos/volker-p/dark-factory-01/target-repo/cmake-build-debug
    [100%] Built target SimulationPathFinder
    --- BUILD SUCCEEDED ---
    --- SUITE OK ---
    Configuration loaded from config.json
    Scenario: STRAIGHT_TUNNEL
      Traversal success : NO
      Steps taken       : 10000
      Distance (cm)     : 19.2
      Min clearance (cm): 9.0
      Near misses       : 6405
      Collisions        : 9960
    Configuration loaded from config.json
    SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS 
    STRAIGHT_TUNNEL       NO       10000   19.2      9.0      6405       9960       
    CORNER_RIGHT          NO       10000   19.2      9.0      6405       9960       
    CORNER_LEFT           NO       10000   18.2      9.0      7310       9962       
    T_JUNCTION            NO       10000   19.2      9.0      6405       9960       
    FOUR_WAY_CROSSING     NO       10000   18.2      9.0      7310       9962       
    --- TRACE FLAG OK ---
    --- TESTS PASSED ---
    ```
- **test_gate**: succeeded
- **review**: succeeded
  - Model: claude-opus-4-7, 58.5k tokens in / 8.8k out
  - Files: /workspace/dark-factory-01/review-report.md
- **gate_pr**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 7.0k tokens in / 892 out
- **test**: succeeded
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    -- Configuring done (0.0s)
    -- Generating done (0.0s)
    -- Build files have been written to: /repos/volker-p/dark-factory-01/target-repo/cmake-build-debug
    [100%] Built target SimulationPathFinder
    --- BUILD SUCCEEDED ---
    --- SUITE OK ---
    Configuration loaded from config.json
    Scenario: STRAIGHT_TUNNEL
      Traversal success : NO
      Steps taken       : 10000
      Distance (cm)     : 19.2
      Min clearance (cm): 9.0
      Near misses       : 6405
      Collisions        : 9960
    Configuration loaded from config.json
    SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS 
    STRAIGHT_TUNNEL       NO       10000   19.2      9.0      6405       9960       
    CORNER_RIGHT          NO       10000   19.2      9.0      6405       9960       
    CORNER_LEFT           NO       10000   18.2      9.0      7310       9962       
    T_JUNCTION            NO       10000   19.2      9.0      6405       9960       
    FOUR_WAY_CROSSING     NO       10000   18.2      9.0      7310       9962       
    --- TRACE FLAG OK ---
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

1. Read the spec at `specs/simulation-path-finder/sensor-config-and-tracing.md` — this is the acceptance criteria.
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