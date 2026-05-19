All nine checklist steps are fully implemented and committed. The diff shows real changes across all six required files with 374 insertions. The implementation is complete:

- **Step 1** (bypass constructor): `Maze::Maze(int w, int h, double cell_size, bool)` in `Maze.cpp`
- **Step 2** (extend `Maze.h`): `ScenarioType` enum, private helpers, public factory/setter
- **Step 3** (`setGoalPosition` + `removeWallBetween`): symmetric wall removal based on dx/dy
- **Step 4** (`createScenario`): per-scenario dimensions, calls bypass constructor + `generateScenario`
- **Step 5** (`generateScenario`): all five geometries with correct wall removals and goal cells
- **Step 6** (`ScenarioSimulation.h`): `ScenarioMetrics` struct + `ScenarioSimulation` class
- **Step 7** (`ScenarioSimulation.cpp`): full simulation loop, collision detection via pose equality, multi-goal `isAtGoal`, `runSuite`
- **Step 8** (`main.cpp`): new includes, helper functions, preliminary scan, scenario dispatch, updated usage
- **Step 9** (`CMakeLists.txt`): `src/ScenarioSimulation.cpp` added to SOURCES