Goal: Implement the spec at specs/simulation-path-finder/wall-follower.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 44.3k tokens in / 9.7k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 27.2k tokens in / 7.9k out
  - Files: /workspace/dark-factory-01/target-repo/src/WallFollower.cpp
- **test**: failed
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    (4 lines omitted)
    [ 14%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/WallFollower.cpp.o
    [ 21%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Renderer.cpp.o
    [  7%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Config.cpp.o
    [ 28%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/DataLogger.cpp.o
    [ 35%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Simulation.cpp.o
    [ 42%] Building CXX object CMakeFiles/SimulationPathFinder.dir/main.cpp.o
    [ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/ScenarioSimulation.cpp.o
    [ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/BatchSimulation.cpp.o
    [ 64%] Linking CXX executable SimulationPathFinder
    [100%] Built target SimulationPathFinder
    --- BUILD SUCCEEDED ---
    --- Checking for banned symbols in WallFollower.cpp ---
    PASS: no relative-turn flags found
    --- Checking Config.h for required fields ---
    PASS: all three config fields present in Config.h
    --- Running scenario: straight_tunnel ---
    Configuration loaded from config.json
    Scenario: STRAIGHT_TUNNEL
      Traversal success : NO
      Steps taken       : 10000
      Distance (cm)     : 22.1
      Min clearance (cm): 9.0
      Near misses       : 9959
      Collisions        : 9954
    ASSERTION FAILED: straight_tunnel did not report Traversal success: YES
    ```
- **test_gate**: succeeded
- **review**: succeeded
  - Model: claude-opus-4-7, 69.3k tokens in / 11.0k out
  - Files: /workspace/dark-factory-01/review-report.md
- **gate_pr**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 27.2k tokens in / 7.9k out
  - Files: /workspace/dark-factory-01/target-repo/src/WallFollower.cpp
- **test**: failed
  - Script: `bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}`
  - Output:
    ```
    (4 lines omitted)
    [ 14%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/WallFollower.cpp.o
    [ 21%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Renderer.cpp.o
    [  7%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Config.cpp.o
    [ 28%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/DataLogger.cpp.o
    [ 35%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Simulation.cpp.o
    [ 42%] Building CXX object CMakeFiles/SimulationPathFinder.dir/main.cpp.o
    [ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/ScenarioSimulation.cpp.o
    [ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/BatchSimulation.cpp.o
    [ 64%] Linking CXX executable SimulationPathFinder
    [100%] Built target SimulationPathFinder
    --- BUILD SUCCEEDED ---
    --- Checking for banned symbols in WallFollower.cpp ---
    PASS: no relative-turn flags found
    --- Checking Config.h for required fields ---
    PASS: all three config fields present in Config.h
    --- Running scenario: straight_tunnel ---
    Configuration loaded from config.json
    Scenario: STRAIGHT_TUNNEL
      Traversal success : NO
      Steps taken       : 10000
      Distance (cm)     : 22.1
      Min clearance (cm): 9.0
      Near misses       : 9959
      Collisions        : 9954
    ASSERTION FAILED: straight_tunnel did not report Traversal success: YES
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

1. Read the spec at `specs/simulation-path-finder/wall-follower.md` — this is the acceptance criteria.
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