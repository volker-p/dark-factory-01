The commit is recorded with real file changes. Here's a summary of everything implemented:

---

## Summary of Changes

### `include/Config.h`
Added three new `WallFollower` algorithm config fields with defaults:
- `wall_follow_kp = 0.5`
- `wall_target_distance_cm = 10.0`
- `angle_tolerance_rad = 0.05`

### `src/Config.cpp`
Added parsing of the three new fields using `nlohmann::json::value()` with defaults — no new JSON keys required in `config.json`.

### `include/WallFollower.h`
**Full rewrite**: Removed 5-state machine, `computeVelocity()`, `updatePosition()`, all setter helpers, `Action`/`State` enums. New interface: `explicit WallFollower(const Config& cfg)` + `void update(Robot& robot, const Maze& maze)`. Private state: `cfg_` reference, `current_heading_rad_`, and `rotateToHeading()` helper.

### `src/WallFollower.cpp`
**Full rewrite**: Implements the stop-scan-drive cycle using absolute-angle arithmetic:
1. Records current absolute heading
2. Rotates to left scan angle (heading + π/2), reads sensor
3. Rotates to right scan angle (heading - π/2), reads sensor
4. Computes new heading: tunnel-centring (R4) or single-wall fallback (R5)
5. Rotates to new heading and drives forward one step

### `include/DataLogger.h`
Moved `Action` enum definition here (was forward-declared before, defined in old `WallFollower.h`).

### `src/DataLogger.cpp`
Removed now-unnecessary `#include "WallFollower.h"`.

### `src/Simulation.cpp`
- Replaced `make_unique<WallFollower>()` + setters with `make_unique<WallFollower>(config)`
- Replaced `computeVelocity`/`getLastAction`/`getState` + `robot->update()` call sequence with single `controller->update(*robot, *maze)`
- Simplified debug logging (removed dead state/action references)
- Passes `Action::FORWARD` as a constant to `logSample()`

### `src/ScenarioSimulation.cpp`
- Replaced `WallFollower()` + setter sequence with `WallFollower controller(config)`
- Replaced `updatePosition` + `computeVelocity` + `robot.update()` with `controller.update(robot, maze)`
- Kept pre-update sensor snapshot for clearance/near-miss metrics