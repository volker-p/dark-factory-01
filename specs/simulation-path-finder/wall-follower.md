<!-- op_work_package_id: 41 -->
---
target_repo: volker-p/SimulationPathFinder
target_branch: master
type: feature
---

# Completely Rewrite Wall Follower Code

## Context

The existing `WallFollower` controller uses relative-angle arithmetic that has
accumulated complexity and edge-case bugs over time.  The rewrite replaces it
with a clean implementation that reasons in **absolute angles** throughout,
eliminating the sources of drift and mis-turn that appear in the current code.

The coordinate convention used everywhere in this project is:
- `theta = 0`     → East (right)
- `theta = PI/2`  → North (up)
- `theta = PI`    → West (left)
- `theta = 3*PI/2`→ South (down)

The robot has **a single front-facing distance sensor**.  To measure distances in
directions other than straight ahead, the robot must stop its forward motion,
rotate to the measurement angle, read the sensor, and then rotate to the chosen
drive heading before moving again.  The rewrite must account for this stop-scan-
drive cycle explicitly; the old code apparently assumed omnidirectional sensing.

The first target algorithm is a **simple tunnel follower**: the robot periodically
stops, sweeps the sensor to the left and right to measure wall distances, computes
a corrected heading from the imbalance, then drives forward on that heading until
the next scan cycle.  This is the simplest meaningful behaviour and is the
baseline all future algorithms must beat on the scenario suite.

---

## Requirements

### R1 — Delete and replace `WallFollower`

Remove the existing implementation of `WallFollower` (`.h` and `.cpp`) and write
a fresh class with the same public interface so callers (`main.cpp`,
`ScenarioSimulation`) require no changes:

```cpp
class WallFollower {
public:
    explicit WallFollower(const Config& cfg);
    void update(Robot& robot, const Maze& maze);
};
```

The old implementation must not survive in any form (no `#ifdef`, no commented-out
code, no `_old` copies).

---

### R2 — Absolute-angle heading

All internal heading computations must use absolute angles in radians measured
from East, CCW positive.  Helper functions that deal with angle wrapping must
use `std::fmod` or equivalent to keep values in `[0, 2*PI)`.  No relative-turn
delta (`turn_left`, `turn_right` boolean flags) may appear in the control loop.

---

### R3 — Scan procedure

Each `update()` call executes one full stop-scan-drive cycle:

1. **Stop** — set linear velocity to 0.
2. **Rotate to left scan angle** — `theta_current + PI/2` (i.e. 90° CCW from
   current heading).  Hold until rotation is complete (robot's heading matches
   target within `cfg.angle_tolerance_rad`).
3. **Read sensor** → `dist_left`.
4. **Rotate to right scan angle** — `theta_current - PI/2` (90° CW from original
   heading).
5. **Read sensor** → `dist_right`.
6. **Compute new heading** (see R4 / R5).
7. **Rotate to new heading**, then **drive forward** at `cfg.robot_speed_cm_s`
   for one drive step before the next `update()` call.

All angle targets use absolute values normalised to `[0, 2*PI)`.

---

### R4 — Tunnel-centring algorithm

When both `dist_left` and `dist_right` are below `cfg.wall_detection_threshold_cm`,
apply a proportional lateral-correction to the current heading:

```
error      = dist_right - dist_left    // positive → too close to right wall
correction = cfg.wall_follow_kp * error
new_theta  = theta_current + correction
```

Clamp `correction` to `[-PI/4, PI/4]` so a single noisy reading cannot reverse
the robot.  Normalise `new_theta` to `[0, 2*PI)`.

---

### R5 — Single-wall fallback

When only one wall is detected (one side below `cfg.wall_detection_threshold_cm`,
the other above it), bias the heading toward the detected wall by
`cfg.wall_follow_kp * (detected_dist - cfg.wall_target_distance_cm)`.
When no wall is detected on either side, maintain the current heading.

---

### R6 — Forward drive

After rotating to `new_theta`, set linear velocity to `cfg.robot_speed_cm_s`
and advance for one simulation step.  The robot does **not** steer while moving;
all steering happens during the stationary scan phase.

---

### R7 — Config keys

The algorithm relies on the following `Config` fields.  Add any that are absent
with the listed defaults:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `wall_follow_kp` | `double` | `0.5` | Proportional gain for lateral error |
| `wall_target_distance_cm` | `double` | `10.0` | Desired distance from a single wall |
| `angle_tolerance_rad` | `double` | `0.05` | Heading error considered "arrived" during rotation |

Do not add new config-file keys beyond these three.

---

## Files to change (expected)

| File | Change |
|------|--------|
| `include/WallFollower.h` | Full rewrite — same public interface, new internals |
| `src/WallFollower.cpp` | Full rewrite — absolute-angle tunnel-centring algorithm |
| `include/Config.h` | Add `wall_follow_kp`, `wall_target_distance_cm`, `angle_tolerance_rad` if missing |
| `src/Config.cpp` | Parse / default the three new fields if missing |

---

## Verification

1. Build succeeds with no warnings (`-Wall -Wextra`) after the rewrite.
2. All existing tests pass (`ctest` or the project's test runner).
3. `--scenario straight_tunnel` completes with `Traversal success: YES`.
4. `--scenario corner_right` and `--scenario corner_left` each complete with
   `Traversal success: YES`.
5. No uses of relative-turn flags (`turn_left`, `turn_right`, `deltaTheta` as a
   boolean) remain in `WallFollower.cpp` after the rewrite.
6. The robot visibly stops before each scan in a headed run (`--render` or log
   output shows zero linear velocity during rotation steps).
