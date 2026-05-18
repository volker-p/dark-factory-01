Goal: Implement the spec at specs/simulation-path-finder/batch-statistics.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 29.1k tokens in / 6.3k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 24.0k tokens in / 3.4k out
  - Files: /workspace/dark-factory-01/target-repo/include/DataLogger.h, /workspace/dark-factory-01/target-repo/include/Simulation.h, /workspace/dark-factory-01/target-repo/src/BatchSimulation.cpp, /workspace/dark-factory-01/target-repo/src/Simulation.cpp
- **test**: failed
  - Script: `bash run-tests.sh 2>&1`
- **test_gate**: succeeded

## Context
- human.gate.gate_plan.answer: A
- human.gate.gate_plan.label: [A] Approve
- human.gate.gate_plan.question: Approve Plan
- human.gate.label: [A] Approve
- human.gate.selected: A


You are an independent senior engineer reviewing a pull request. You did not write this code.

## Steps

1. Read the spec at `specs/simulation-path-finder/batch-statistics.md` — this is the acceptance criteria.
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