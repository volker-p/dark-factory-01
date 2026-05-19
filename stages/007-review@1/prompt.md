Goal: Implement the spec at specs/simulation-path-finder/scenario-testing.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 34.7k tokens in / 8.7k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 40.9k tokens in / 9.8k out
  - Files: /workspace/dark-factory-01/target-repo/CMakeLists.txt, /workspace/dark-factory-01/target-repo/include/Maze.h, /workspace/dark-factory-01/target-repo/include/ScenarioSimulation.h, /workspace/dark-factory-01/target-repo/main.cpp, /workspace/dark-factory-01/target-repo/src/Maze.cpp, /workspace/dark-factory-01/target-repo/src/ScenarioSimulation.cpp
- **test**: succeeded
  - Script: `bash run-tests.sh 2>&1`
  - Output:
    ```
    (39218 lines omitted)
    ⚠️ RECOVERY BLOCKED! Backup failed for 30 steps. Robot trapped in corner.
    ⚠️ Trying forward escape (front: 18 cm)
    ⚠️ DESPERATE exit (step 0, front: 16 cm) → FOLLOW_WALL
    Obstacle ahead! → AVOID_COLLISION
    ⚠️ STUCK DETECTED! Position unchanged for 10 steps. Forcing RECOVERY.
    ⚠️ Backup phase done - scanning for clearance
    ⚠️ RECOVERY BLOCKED! Backup failed for 30 steps. Robot trapped in corner.
    ⚠️ Trying forward escape (front: 21 cm)
    ⚠️ DESPERATE exit (step 0, front: 21 cm) → FOLLOW_WALL
    Obstacle ahead! → AVOID_COLLISION
    ⚠️ STUCK DETECTED! Position unchanged for 10 steps. Forcing RECOVERY.
    ⚠️ Backup phase done - scanning for clearance
    ✓ RECOVERY successful (step 0, front: 36 cm) → FOLLOW_WALL
    ⚠️ STUCK DETECTED! Position unchanged for 10 steps. Forcing RECOVERY.
    ✓ RECOVERY successful (step 0, front: 100 cm) → FOLLOW_WALL
    ⚠️ STUCK DETECTED! Position unchanged for 10 steps. Forcing RECOVERY.
    ✓ RECOVERY successful (step 0, front: 51 cm) → FOLLOW_WALL
    ⚠️ STUCK DETECTED! Position unchanged for 10 steps. Forcing RECOVERY.
    ✓ RECOVERY successful (step 0, front: 39 cm) → FOLLOW_WALL
    SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS 
    STRAIGHT_TUNNEL       NO       10000   1446.6    14.0     2638       3795       
    CORNER_RIGHT          NO       10000   1446.6    14.0     2638       3795       
    CORNER_LEFT           NO       10000   1446.6    14.0     2638       3795       
    T_JUNCTION            NO       10000   1446.6    14.0     2638       3795       
    FOUR_WAY_CROSSING     NO       10000   1446.6    14.0     2638       3795
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

1. Read the spec at `specs/simulation-path-finder/scenario-testing.md` — this is the acceptance criteria.
2. Get the full diff:
   ```bash
   cd target-repo && git diff HEAD
   ```
3. Read `target-repo/AGENTS.md` to understand the project conventions.

## Write a satisfaction report to `review-report.md`

Structure it as follows:

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