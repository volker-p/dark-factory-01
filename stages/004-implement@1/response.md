The commit is recorded with real file changes across all 9 required files. Here's a summary of what was implemented:

## Summary of Changes

### `config.json`
- Updated `robot.radius_cm` from `15` → `10`
- Added `"minimum_distance_to_wall": 10` under `robot`

### `include/Config.h`
- Added `double minimum_distance_to_wall` field to Robot configuration section
- Added `bool debug` field (runtime flag, not loaded from JSON)

### `src/Config.cpp`
- Loads `minimum_distance_to_wall` from `j["robot"]["minimum_distance_to_wall"]`
- Initialises `config.debug = false` before `validate()`

### `include/WallFollower.h`
- Changed `bool debug_ = true` → `bool debug_ = false`
- Added public `void setDebug(bool d) { debug_ = d; }` method

### `src/WallFollower.cpp`
- Replaced every `std::cout` debug print with `std::cerr` (all 20+ occurrences)
- Replaced hard-coded `robot_radius_cm + 10.0` / `+ 5.0` with `config.minimum_distance_to_wall`-based expressions
- Removed redundant `right_side` / `right_mean` alias — now uses `right_mean = sensors[2]` directly

### `src/Simulation.cpp`
- Added `controller->setDebug(config.debug)` after constructing `WallFollower`
- Gated `initializeRobot()` debug output behind `if (config.debug)`
- Gated verbose step-logging block behind `if (config.debug && should_log)`

### `main.cpp`
- Added `bool debug = false;` local variable
- Added `--debug` to preliminary pass (no-op to avoid "Unknown option" error)
- Added `--debug` to main parse loop setting `debug = true`
- Sets `config.debug = debug` after loading config
- Added `--debug` description to `printUsage()`

### `src/ScenarioSimulation.cpp`
- Added `controller.setDebug(config.debug)` after constructing `WallFollower`

### `include/Maze.h`
- Removed the two unimplemented declarations `hasWall` and `isWallBetween` (no callers exist)