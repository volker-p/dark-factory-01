Goal: Implement the spec at specs/simulation-path-finder/batch-statistics.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 28.2k tokens in / 7.0k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 17.0k tokens in / 3.1k out
  - Files: /workspace/dark-factory-01/target-repo/include/DataLogger.h, /workspace/dark-factory-01/target-repo/include/Simulation.h, /workspace/dark-factory-01/target-repo/src/BatchSimulation.cpp
- **test**: failed
  - Script: `bash run-tests.sh 2>&1`
  - Output:
    ```
    (504 lines omitted)
    Setting up libwayland-dev:amd64 (1.22.0-2.1build1) ...
    Setting up libdecor-0-dev:amd64 (0.2.2-1build2) ...
    Setting up libpulse-mainloop-glib0:amd64 (1:16.1+dfsg1-2ubuntu10.1) ...
    Setting up libpulse-dev:amd64 (1:16.1+dfsg1-2ubuntu10.1) ...
    Setting up mesa-libgallium:amd64 (25.2.8-0ubuntu0.24.04.1) ...
    Setting up libdrm-dev:amd64 (2.4.125-1ubuntu0.1~24.04.1) ...
    Setting up libgbm1:amd64 (25.2.8-0ubuntu0.24.04.1) ...
    Setting up libgl1-mesa-dri:amd64 (25.2.8-0ubuntu0.24.04.1) ...
    Setting up libgbm-dev:amd64 (25.2.8-0ubuntu0.24.04.1) ...
    Setting up libegl-mesa0:amd64 (25.2.8-0ubuntu0.24.04.1) ...
    Setting up libegl1:amd64 (1.7.0-1build1) ...
    Setting up libsdl2-2.0-0:amd64 (2.30.0+dfsg-1ubuntu3.1) ...
    Setting up libglx-mesa0:amd64 (25.2.8-0ubuntu0.24.04.1) ...
    Setting up libglx0:amd64 (1.7.0-1build1) ...
    Setting up libgl1:amd64 (1.7.0-1build1) ...
    Setting up libglx-dev:amd64 (1.7.0-1build1) ...
    Setting up libgl-dev:amd64 (1.7.0-1build1) ...
    Setting up libegl-dev:amd64 (1.7.0-1build1) ...
    Setting up libgles-dev:amd64 (1.7.0-1build1) ...
    Processing triggers for libc-bin (2.39-0ubuntu8.7) ...
    Processing triggers for sgml-base (1.31) ...
    Setting up libdbus-1-dev:amd64 (1.14.10-4ubuntu4.1) ...
    Setting up libibus-1.0-dev:amd64 (1.5.29-2) ...
    Setting up libsdl2-dev:amd64 (2.30.0+dfsg-1ubuntu3.1) ...
    run-tests.sh: line 18: cmake: command not found
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