The rework is complete and verified. Here's a summary of everything that was done:

## Summary of Changes

### Blocking Items Fixed (from review-report.md)

**Item 1 — R1 regression: Hard-coded `15.0` robot radius removed**
- `include/WallFollower.h`: Changed `robot_radius_cm_ = 15.0` → `10.0` (matches config), added `setRobotRadius(double r)` and `setMinDistanceToWall(double d)` public setters
- `src/Simulation.cpp`: Added `controller->setRobotRadius(config.robot_radius_cm)` and `controller->setMinDistanceToWall(config.minimum_distance_to_wall_cm)` after construction
- `src/ScenarioSimulation.cpp`: Same — added both setters after `setDebug()`

**Item 2 — `minimum_distance_to_wall_cm` now actually consumed**
- Added `min_distance_to_wall_cm_` member to `WallFollower`
- `src/WallFollower.cpp`: Lines 164/167 now use `robot_radius_cm_ + min_distance_to_wall_cm_` and `robot_radius_cm_ + min_distance_to_wall_cm_ * 0.5` instead of the magic numbers `+10.0` and `+5.0`

### Non-Blocking Items Fixed

**Item 3 — Trailing newlines restored** on `include/Config.h`, `src/Simulation.cpp`, `src/ScenarioSimulation.cpp`

**Item 4 — Dead `--debug` preliminary-pass branch removed** from `main.cpp:86-89`

**Item 5 — Pre-existing `-Wall` warnings resolved:**
- `src/Maze.cpp`: Reordered constructor init list to match declaration order (fixes `-Wreorder` for `Maze::cell_size_cm`)
- `src/PerformanceMetrics.cpp`: Reordered constructor init list (fixes `-Wreorder` for `PerformanceMetrics::stuck_step_count`)
- `src/Pathfinder.cpp`: Removed unused `bool found = false` variable (fixes `-Wunused-but-set-variable`)
- `src/SensorNoise.cpp`: Reordered constructor init list (fixes `-Wreorder` for `SensorNoise::sigma`)

The build now produces **zero `-Wall` warnings** and all functional tests continue to pass.