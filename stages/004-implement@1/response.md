The commit is recorded with real file changes across all 6 files. Here's a summary of everything implemented:

## Summary

All 9 checklist items from `plan.md` have been implemented:

1. **Bypass constructor in `Maze`** — Private `Maze(int w, int h, double cell_size, bool /*tag*/)` that initialises the grid without calling `generateRecursiveBacktracking` or `setRandomGoal`.

2. **`Maze.h` extended** — Added `ScenarioType` enum class (5 variants), private `removeWallBetween` and `generateScenario` helpers, public `setGoalPosition` setter, and `static createScenario` factory.

3. **`Maze::setGoalPosition` and `Maze::removeWallBetween`** — Implemented symmetrically (removes both cells' shared wall based on relative dx/dy direction).

4. **`Maze::createScenario`** — Determines grid dimensions per scenario type, constructs via bypass constructor, calls `generateScenario`, returns the maze.

5. **`Maze::generateScenario`** — Implements all five scenario geometries (STRAIGHT_TUNNEL 3×5, CORNER_RIGHT 5×4, CORNER_LEFT 5×4, T_JUNCTION 5×5, FOUR_WAY_CROSSING 5×5) with correct wall removals and goal placement.

6. **`include/ScenarioSimulation.h`** — New file declaring `ScenarioMetrics` struct and `ScenarioSimulation` class with `runScenario`, `runSuite`, and private `isAtGoal`.

7. **`src/ScenarioSimulation.cpp`** — Full implementation: constructor stores config; `runScenario` sets up maze+robot+controller, runs headlessly up to `max_steps`, tracks min clearance, near-misses, collisions, and stops early at goal; `isAtGoal` checks primary goal plus alternate cells for T_JUNCTION/FOUR_WAY_CROSSING; `runSuite` iterates all five types.

8. **`main.cpp`** — Added `#include "ScenarioSimulation.h"`, `scenarioName` helper, `printSingleScenario` and `printSuiteTable` formatters, updated `printUsage`, preliminary arg scan for `--scenario`/`--scenario-suite`, and scenario dispatch block after config loading.

9. **`CMakeLists.txt`** — `src/ScenarioSimulation.cpp` appended to `SOURCES`.