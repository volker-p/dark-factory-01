Both files are written. Here's a summary of what was produced:

---

## `plan.md` — Summary

**Goal:** Make `config.json` the single source of truth for physical constants, add a `--debug` CLI flag (default off), improve `WallFollower`, and clean up the `Maze` interface.

### Key findings from reading the codebase:

1. **`config.json`** — `cell_size_cm` is already 50 ✓. Only `robot.radius_cm` needs to change (15→10) and `minimum_distance_to_wall: 10` needs to be added.

2. **`Maze::hasWall` / `isWallBetween`** — confirmed **zero callers** in the entire codebase. The clean choice is **removal** from `Maze.h` (no `.cpp` implementation needed).

3. **`WallFollower.cpp`** — uses `extern Config config;` global and already references `config.robot_radius_cm`. The safe-distance literals (`+10.0`, `+5.0`) will become `config.minimum_distance_to_wall`-based. All `std::cout` debug prints→`std::cerr`.

4. **`Simulation.cpp`** — contains a large verbose step-logging block that always fires; this gets gated behind `config.debug`.

5. **`Config`** — needs two new fields: `double minimum_distance_to_wall` (loaded from JSON) and `bool debug` (set by CLI, defaulting `false`).

6. **`ScenarioSimulation.cpp`** — already reads `config.cell_size_cm` correctly; just needs `controller.setDebug(config.debug)`.

### The plan covers 10 numbered steps with exact code snippets, a test strategy with 3 new shell checks, and a risk table with 7 edge cases.

---

## `run-tests.sh` — Summary

- Installs `cmake build-essential git libsdl2-dev` if cmake is absent
- Initialises git submodules (for `nlohmann/json`)
- Configures with `-Wall -Wextra -Werror` to enforce the zero-warnings constraint
- Builds with parallel jobs
- Runs: headless batch (3 runs), full scenario suite, and the `--debug`→stderr verification