Goal: Implement the spec at specs/simulation-path-finder/config-and-debug.md in the target repository and open a pull request

## Completed stages
- **plan**: succeeded
  - Model: claude-sonnet-4-6, 43.7k tokens in / 6.6k out
  - Files: /workspace/dark-factory-01/plan.md, /workspace/dark-factory-01/run-tests.sh
- **gate_plan**: succeeded
- **implement**: succeeded
  - Model: claude-sonnet-4-6, 55.4k tokens in / 13.9k out
  - Files: /workspace/dark-factory-01/target-repo/config.json, /workspace/dark-factory-01/target-repo/include/Config.h, /workspace/dark-factory-01/target-repo/include/Maze.h, /workspace/dark-factory-01/target-repo/include/WallFollower.h, /workspace/dark-factory-01/target-repo/main.cpp, /workspace/dark-factory-01/target-repo/src/Config.cpp, /workspace/dark-factory-01/target-repo/src/ScenarioSimulation.cpp, /workspace/dark-factory-01/target-repo/src/Simulation.cpp, /workspace/dark-factory-01/target-repo/src/WallFollower.cpp
- **test**: failed
  - Script: `bash run-tests.sh 2>&1`
  - Output:
    ```
    (583 lines omitted)
          |            ^~~~~
    /repos/volker-p/dark-factory-01/target-repo/include/SensorNoise.h:9:38: error:   'std::normal_distribution<double> SensorNoise::distribution' [-Werror=reorder]
        9 |     std::normal_distribution<double> distribution;
          |                                      ^~~~~~~~~~~~
    /repos/volker-p/dark-factory-01/target-repo/src/SensorNoise.cpp:4:1: error:   when initialized here [-Werror=reorder]
        4 | SensorNoise::SensorNoise(double sigma_cm, unsigned int seed)
          | ^~~~~~~~~~~
    In file included from /repos/volker-p/dark-factory-01/target-repo/src/Maze.cpp:1:
    /repos/volker-p/dark-factory-01/target-repo/include/Maze.h: In constructor 'Maze::Maze(int, int, double, bool)':
    /repos/volker-p/dark-factory-01/target-repo/include/Maze.h:36:12: error: 'Maze::cell_size_cm' will be initialized after [-Werror=reorder]
       36 |     double cell_size_cm;
          |            ^~~~~~~~~~~~
    /repos/volker-p/dark-factory-01/target-repo/include/Maze.h:34:9: error:   'int Maze::width_cells' [-Werror=reorder]
       34 |     int width_cells;
          |         ^~~~~~~~~~~
    /repos/volker-p/dark-factory-01/target-repo/src/Maze.cpp:87:1: error:   when initialized here [-Werror=reorder]
       87 | Maze::Maze(int w, int h, double cell_size, bool /*tag*/)
          | ^~~~
    cc1plus: all warnings being treated as errors
    gmake[2]: *** [CMakeFiles/SimulationPathFinder.dir/build.make:118: CMakeFiles/SimulationPathFinder.dir/src/SensorNoise.cpp.o] Error 1
    gmake[2]: *** Waiting for unfinished jobs....
    cc1plus: all warnings being treated as errors
    gmake[2]: *** [CMakeFiles/SimulationPathFinder.dir/build.make:90: CMakeFiles/SimulationPathFinder.dir/src/Maze.cpp.o] Error 1
    gmake[1]: *** [CMakeFiles/Makefile2:83: CMakeFiles/SimulationPathFinder.dir/all] Error 2
    gmake: *** [Makefile:91: all] Error 2
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