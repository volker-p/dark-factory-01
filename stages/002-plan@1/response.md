Both files are written and the script is executable. Here's a summary of what was produced:

---

## Summary

### What I read
- **Spec** (`specs/simulation-path-finder/scenario-testing.md`): `target_repo = volker-p/SimulationPathFinder`, `type = feature`. Extracted all 6 requirements (R1–R6) and 6 file-change targets.
- **Cloned repo** and read: `CLAUDE.md` (build/architecture docs), `CMakeLists.txt`, `include/Maze.h`, `src/Maze.cpp`, `include/Robot.h`, `src/Robot.cpp`, `include/Config.h`, `include/WallFollower.h`, `src/Simulation.cpp`, `main.cpp`, `include/BatchSimulation.h`, plus all build scripts.

### `plan.md` covers
1. **Goal** — one sentence
2. **Files to change** — table with all 6 entries (4 modified, 2 new)
3. **Implementation checklist** — 9 concrete steps, each with exact code snippets or pseudocode a junior developer can follow:
   - Steps 1–5: `Maze` changes (bypass constructor, `ScenarioType` enum, `setGoalPosition`, `removeWallBetween`, `createScenario`, `generateScenario` geometries)
   - Steps 6–7: new `ScenarioSimulation` header and implementation (incl. the heading angle gotcha resolved from kinematics)
   - Step 8: `main.cpp` CLI extension
   - Step 9: `CMakeLists.txt` addition
4. **Test strategy** — 5 CLI smoke tests + unit-level checks + confirmation existing tests are unaffected
5. **Risks and edge cases** — 7 items including the heading direction ambiguity, cell-size vs robot-radius fit, float equality for collision detection, multi-goal scenarios, and SDL2 linkage

### `run-tests.sh`
- Installs `cmake`, `build-essential`, `git`, `libsdl2-dev` (handles both cmake-absent and cmake-present-but-SDL2-absent cases)
- Initialises the `nlohmann/json` submodule
- Configures and builds via CMake
- Runs 3 tests: existing batch smoke, single-scenario run, full suite run