Both files are written. Here's a summary of what was produced:

---

## What was done

### 1. Read and understood the spec
- **Target repo**: `volker-p/SimulationPathFinder` (cloned into `target-repo/`)
- **Type**: bugfix
- **4 requirements**: unified physical config (R1), `--debug` flag (R2), WallFollower improvements (R3), clean Maze interface (R4)

### 2. Key findings from reading the codebase

| Finding | Impact on plan |
|---|---|
| `config.json` already has `cell_size_cm: 50`; `robot_radius_cm` is 15 (needs → 10) | Only `radius_cm` and `minimum_distance_to_wall` need adding to JSON |
| `ScenarioSimulation.cpp` already reads `config.cell_size_cm` — no literal `20` | Spec's "hard-coded cell_size_cm" bug was already fixed in a prior commit; verify only |
| `hasWall` / `isWallBetween` declared in `Maze.h` but **zero callers, zero implementations** | Decision: remove declarations (cleanest option) |
| `WallFollower.debug_` initialised `true`, all debug output goes to `std::cout` | Needs: default → `false`, add `setDebug()`, reroute to `std::cerr` |
| `Simulation.cpp` has a large always-on verbose step-logging block outputting to `std::cout` | Must be gated behind `debug_` flag |
| `inner_radius = 18.0` hard-coded in `WallFollower.cpp` | Should come from `config.minimum_distance_to_wall` |
| Build uses CMake 3.16+, C++20, SDL2, nlohmann/json submodule | Informs `run-tests.sh` dependencies |

### 3. Outputs
- **`plan.md`** — complete plan with goal, 11-row files table, 10-step implementation checklist, test strategy, and risks/edge cases table
- **`run-tests.sh`** — installs SDL2, initialises submodules, builds with `cmake -B build`, then runs 4 acceptance checks that map directly to the spec's verification commands; prints `--- BUILD SUCCEEDED ---` and `--- TESTS PASSED ---` markers