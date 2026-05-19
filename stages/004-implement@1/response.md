The commit is in place. Here's a summary of everything implemented:

## Summary

All 10 checklist items from `plan.md` have been implemented:

### Changes Made

1. **`config.json`** — Changed `robot.radius_cm` from `15` → `10`, added `"minimum_distance_to_wall": 10`.

2. **`include/Config.h`** — Added `double minimum_distance_to_wall_cm` field (robot config section) and `bool debug = false` runtime flag.

3. **`src/Config.cpp`** — Added loader for `config.minimum_distance_to_wall_cm = j["robot"]["minimum_distance_to_wall"]`.

4. **`include/WallFollower.h`** — Changed `debug_ = true` → `false`, added public `void setDebug(bool d)` method, added `double robot_radius_cm_ = 15.0` private member.

5. **`main.cpp`** — Added `bool debug_flag = false`, `--debug` branch in argument parser, `if (debug_flag) config.debug = true` after config load, updated `printUsage()`, and added `--debug` to preliminary pass.

6. **`src/WallFollower.cpp`** — Removed `#include "Config.h"` and `extern Config config;`, replaced `config.robot_radius_cm` with `robot_radius_cm_`, replaced the wasteful `right_mean` alias with direct `right_side` usage, and converted all ~20 `std::cout` debug calls to `std::cerr`.

7. **`src/Simulation.cpp`** — Added `controller->setDebug(config.debug)` after construction, gated the step-logging block behind `config.debug && should_log`, gated `initializeRobot()` debug prints behind `config.debug`.

8. **`src/ScenarioSimulation.cpp`** — Added `controller.setDebug(config.debug)` after construction.

9. **`include/Maze.h`** — Removed the two unimplemented declarations `hasWall` and `isWallBetween` (no callers confirmed).