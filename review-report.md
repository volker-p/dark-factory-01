# Review Report — Completely Rewrite Wall Follower Code (Round 2)

Spec: `specs/simulation-path-finder/wall-follower.md`
Target: `volker-p/SimulationPathFinder` @ `master`

This is the **second** review pass after a prior `REQUEST CHANGES` verdict on the same
spec. The previous review flagged the `straight_tunnel` scenario failure (19.7 cm
travelled, 9 959 collisions) as a blocking issue. The current implementation has
been re-run and **the same scenario still fails with essentially the same
symptoms** — see Test Results below.

---

## Test Results

**FAILED.** Build and static checks pass, but the very first scenario assertion
(`straight_tunnel`) fails. The remaining scenarios were not reached because
`run-tests.sh` uses `set -euo pipefail`.

Full output from `test-output.txt`:

```
-- Configuring done (0.0s)
-- Generating done (0.0s)
-- Build files have been written to: /repos/volker-p/dark-factory-01/target-repo/cmake-build-debug
--- CMAKE CONFIGURE SUCCEEDED ---
[ 14%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/WallFollower.cpp.o
[ 21%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Renderer.cpp.o
[  7%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Config.cpp.o
[ 28%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/DataLogger.cpp.o
[ 35%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Simulation.cpp.o
[ 42%] Building CXX object CMakeFiles/SimulationPathFinder.dir/main.cpp.o
[ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/ScenarioSimulation.cpp.o
[ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/BatchSimulation.cpp.o
[ 64%] Linking CXX executable SimulationPathFinder
[100%] Built target SimulationPathFinder
--- BUILD SUCCEEDED ---
--- Checking for banned symbols in WallFollower.cpp ---
PASS: no relative-turn flags found
--- Checking Config.h for required fields ---
PASS: all three config fields present in Config.h
--- Running scenario: straight_tunnel ---
Configuration loaded from config.json
Scenario: STRAIGHT_TUNNEL
  Traversal success : NO
  Steps taken       : 10000
  Distance (cm)     : 22.1
  Min clearance (cm): 9.0
  Near misses       : 9959
  Collisions        : 9954
ASSERTION FAILED: straight_tunnel did not report Traversal success: YES
```

Comparison with previous round:

| Metric | Previous run | This run | Delta |
|---|---|---|---|
| Traversal success | NO | NO | unchanged |
| Distance (cm) | 19.7 | 22.1 | +2.4 cm (still ~99 % stuck) |
| Near misses | 9 966 | 9 959 | −7 |
| Collisions | 9 954 | 9 954 | unchanged |

The numerical drift between runs is consistent with the `scanReading()` helper
having been added (averaging sensors 0 and 1 instead of taking only sensor 0),
but **the macro-behaviour is identical**: the robot wedges itself against a wall
and stays there for the full 10 000 step budget.

Notes on warnings: the build log shows no warning lines, but `run-tests.sh:22`
configures with `-DCMAKE_BUILD_TYPE=Debug` only; whether the project's
`CMakeLists.txt` adds `-Wall -Wextra` cannot be confirmed from the artifact
alone (Spec Verification item 1).

`corner_right`, `corner_left`, `--scenario-suite` and the batch smoke test were
never executed because the test script aborted at the straight-tunnel
assertion. Verification items 4 (corner scenarios) and 2 (existing tests) are
unverified for the same reason.

---

## Requirements

### R1 — Delete and replace `WallFollower` — ✅ Met
- `include/WallFollower.h:1-18` — fully rewritten to the mandated interface
  (`explicit WallFollower(const Config&)`, `void update(Robot&, const Maze&)`).
- `src/WallFollower.cpp` — 98 lines, all-new, no `#ifdef`, no commented-out old
  code.
- Old `State`/`Action` enums, setters, `computeVelocity`, `updatePosition`,
  `forceRecovery`, `isStuck`, `getLastAction`, `getState`, `reset`, etc. are
  gone (`git diff` confirms full deletion from header and `.cpp`).
- Side-effect: the `Action` enum that previously lived in `WallFollower.h` has
  been **relocated to `include/DataLogger.h:11-18`**. This is needed because
  `DataLogger::logSample` still takes an `Action` parameter and `Simulation.cpp`
  still passes one. Reasonable, but a header-relocation that the human
  reviewer should be aware of.

### R2 — Absolute-angle heading — ✅ Met
- All heading computations use absolute radians: `current_heading_rad_`,
  `left_angle = current_heading + PI/2`, `right_angle = current_heading - PI/2`,
  `new_heading = current + correction` (`src/WallFollower.cpp:46-97`).
- `normalise()` uses `std::fmod` and brings values into `[0, 2π)`
  (`src/WallFollower.cpp:11-15`).
- No `turn_left` / `turn_right` / `deltaTheta` boolean flags anywhere — the
  `run-tests.sh` grep check passes.

### R3 — Scan procedure — ⚠️ Partial
Seven-step sequence is structurally implemented in `update()`
(`src/WallFollower.cpp:46-97`):
1. Stop & record heading — ✅ (`:48-49`)
2. Rotate to left scan angle — ✅ (`:52-53`)
3. Read sensor → `dist_left` — ⚠️ uses `scanReading(readings)` which averages
   the −15° and +15° sensors (`:42-44`, called at `:58`). This is an improvement
   over the previous round (which used `readings[0]` alone), and is now
   geometrically symmetric around the scan heading.
4. Rotate to right scan angle — ✅ (`:61-62`)
5. Read sensor → `dist_right` — ⚠️ same symmetric average (`:66`).
6. Compute new heading — ✅ (`:71-92`)
7. Rotate to new heading, drive forward one step — ✅ (`:95-97`)

Stop semantics during scans are correct: `rotateToHeading()`
(`src/WallFollower.cpp:24-37`) always passes `linear_vel = 0.0` to
`robot.update()` (`:35`), so Verification item 6 (zero linear velocity during
rotation) is satisfied.

**Note on the sensor change:** the symmetric-average fix addresses one of the
three blocking items from the previous review. However, the algorithm still
fails identically — see R4.

### R4 — Tunnel-centring algorithm — ⚠️ Partial (still divergent)
The formula matches the spec literally (`src/WallFollower.cpp:76-80`):
```cpp
double error      = dist_right - dist_left;
double correction = clamp(cfg_.wall_follow_kp * error, -PI / 4.0, PI / 4.0);
new_heading = normalise(current_heading_rad_ + correction);
```
`kp = 0.5` default, clamp to `[-π/4, π/4]`, normalise applied — all per spec.

The dimensional concern from the previous review remains: in a 50 cm cell with
`sensor_noise_sigma_cm = 2.0`, a 4 cm noise-driven difference yields
`correction = 0.5 × 4 = 2.0 rad ≈ 115°`, clamped to 45° every scan cycle. The
implementation faithfully reproduces the formula and the spec's default
constant; the runtime failure indicates that either the formula, the constant,
or the surrounding scan geometry is wrong, but **the implementer made no
changes to address this on round 2.** The sensor-averaging fix narrows the
asymmetric component of the error but does nothing about the gain scale.

### R5 — Single-wall fallback — ⚠️ Partial (unreachable in the test suite)
Implemented at `src/WallFollower.cpp:81-92`. The code matches the spec wording.

Concerns (unchanged from the previous review):
- **Detection threshold**: R4/R5 reference `cfg.wall_detection_threshold_cm`,
  which is not in `Config` (R7 forbids adding any 4th key). The implementation
  uses `cfg_.sensor_range_cm` (= 100 cm) as the threshold (`:71`). In a 50 cm
  cell every reading is below 100 cm, so the single-wall and no-wall branches
  are effectively dead code in the failing scenario; only R4 fires.
- **Sign convention in the single-wall branches**: with CCW-positive headings,
  the right branch subtracts (`:84`) and the left branch adds (`:88`). This is
  consistent with "bias toward the wall", but is unverified because the branch
  is unreachable in the current test set.

### R6 — Forward drive — ✅ Met
`src/WallFollower.cpp:96` calls
`robot.update(cfg_.timestep_s, cfg_.linear_velocity_cm_per_s, 0.0, maze)` —
linear speed from config, zero angular, single physics step, after rotation
completes. No steering while moving.

### R7 — Config keys — ✅ Met
- `include/Config.h:47-50` adds the three fields with correct defaults
  (`0.5`, `10.0`, `0.05`).
- `src/Config.cpp` parses them with `j.value(..., default)` so `config.json`
  needs no modification.
- No fourth key is introduced.

### Verification items from the spec

| Item | Status | Evidence |
|---|---|---|
| 1. Build succeeds with no warnings (`-Wall -Wextra`) | ⚠️ Build succeeds; `-Wextra` is not explicitly enabled in the captured CMake invocation, so "no warnings" cannot be fully confirmed from the artifact. |
| 2. Existing tests pass | n/a — repo has no `ctest` suite. |
| 3. `--scenario straight_tunnel` → `Traversal success: YES` | ❌ **NO** — 22.1 cm traversal, 9 954 collisions. |
| 4. `corner_right` / `corner_left` → `YES` | ❌ Not executed (pipeline aborted at step 3). |
| 5. No relative-turn flags in `WallFollower.cpp` | ✅ grep check passes. |
| 6. Robot stops before each scan | ✅ `rotateToHeading()` always passes `linear_vel = 0.0`. |

---

## Test Coverage

- No `ctest` suite exists; verification rides on `run-tests.sh` which runs the
  three mandated scenarios + `--scenario-suite` + a batch smoke test.
- The test ordering is appropriate: `straight_tunnel` is the simplest possible
  scenario; if the algorithm cannot pass it, no harder scenario can pass.
- **The test pipeline can only verify the algorithm is correct, not that the
  fix landed.** The implementation in this round changed the sensor read from
  `readings[0]` to a `(readings[0]+readings[1])/2` symmetric average, but
  produced essentially identical scenario output. There is no per-step trace
  in the test artifact, so we cannot tell from the test output alone whether
  the robot is failing at the first scan, the heading-compute step, or
  somewhere later. A debug log of `(theta_pre, dist_left, dist_right, error,
  correction, theta_post)` for the first ~10 scan cycles would have been
  invaluable here.
- Edge cases in the spec that are **not** covered by any test:
  - R5 single-wall branch (no scenario in the suite has only one wall in the
    100 cm sensor range with a 50 cm cell).
  - R5 no-wall branch (impossible with 100 cm sensor range and ≤500 cm maze).
  - `angle_tolerance_rad` parameter sensitivity (no test varies it).
- `ScenarioSimulation.cpp:54-62` clearance/collision counters are meaningful
  enough to catch the "wedged against wall" failure mode that this run exhibits.

---

## Code Quality

**Conventions:** Repository has no `AGENTS.md`. The diff respects the existing
file layout (`include/` headers, `src/` implementations), the existing CMake
build, and `nlohmann::json`'s `j.value(key, default)` style. Indent (4 spaces),
naming (`snake_case_` trailing-underscore for private members) matches the
file being replaced.

**Specific issues for a human reviewer:**

1. **Algorithm still diverges (blocking).** `src/WallFollower.cpp:76-80` — `kp =
   0.5` rad/cm applied to a raw cm error continues to produce 45°-clamped
   swings every scan cycle in a 50 cm tunnel. The previous review identified
   this exact issue; this round addressed only the sensor-asymmetry component
   (point 2 below), not the gain-scale component. The catastrophic failure is
   unchanged.

2. **Sensor-averaging change.** `src/WallFollower.cpp:42-44` introduces
   `scanReading()` which averages `readings[0]` (−15°) and `readings[1]`
   (+15°). After rotating to the left-scan heading, those rays now point at
   `heading + 90° − 15° = +75°` and `heading + 90° + 15° = +105°`,
   geometrically symmetric around the nominal left direction. This is a
   genuine improvement over the previous round's `readings[0]` alone. It does
   **not**, however, fix the gain-scale problem and is therefore insufficient
   on its own.

3. **`Action` enum still relocated into `DataLogger.h`** (`include/DataLogger.h:11-18`).
   `Simulation.cpp` continues to hard-code `Action::FORWARD` for every logged
   sample. If any downstream consumer depends on the per-step action column,
   it is now a constant. Out of scope for this spec but worth flagging.

4. **`rotateToHeading` max-step bound** — 500 inner steps × up to 3 calls per
   `update()` × up to 10 000 outer steps = up to 15 M physics ticks per
   scenario. The test ran to completion, so this is not currently
   wall-clock-blocking, but it is fragile.

5. **Missing trailing newlines** at the end of `include/DataLogger.h`,
   `include/WallFollower.h`, and `src/WallFollower.cpp` (the diff shows
   `\ No newline at end of file`). Minor; not enforced by this repo's
   conventions, but POSIX-strict tooling will warn.

6. **No defensive check that `readings.size() >= 2`** in `scanReading()`
   (`src/WallFollower.cpp:42-44`) or before the calls at `:58, :66`. The
   call-site guarantees four sensors via `config.json`, so this is safe today,
   but a single-sensor config would index out of bounds.

7. **Round 2 made effectively no progress on the blocking item.** The
   `implement` stage was re-run between rounds 1 and 2 with the same model and
   the same token budget (27.2k / 7.9k — identical numbers), and produced what
   is functionally the same code with a sensor-averaging tweak. Without a
   different intervention (a debug trace, a tuning pass on `kp`, or a
   re-reading of the spec to identify what "imbalance" really means), a third
   `implement` run is unlikely to fix this.

---

## Verdict

### REQUEST CHANGES

Blocking items (must be fixed before merge):

1. **`straight_tunnel` scenario still fails** with 22.1 cm of travel and
   9 954 collisions / 10 000 steps. Spec Verification item 3 explicitly
   requires `Traversal success: YES`. This is the **same blocking item** from
   the previous review; the round-2 change (sensor averaging in
   `src/WallFollower.cpp:42-44`) was a partial fix that did not move the needle
   on the actual failure mode.
2. **Scenarios `corner_right` and `corner_left` are still unverified**
   because `run-tests.sh` aborts at the straight-tunnel assertion. Spec
   Verification item 4 requires both to succeed.
3. **Address the gain-scale issue in R4**, not just the sensor symmetry. With
   `kp = 0.5` and raw centimetre error, the lateral correction saturates at 45°
   for any noise-level wall imbalance, which combined with the rotate-to-new-
   heading step prevents forward progress. Options to investigate (in priority
   order):
     - Normalise the error in `src/WallFollower.cpp:78` by
       `wall_target_distance_cm` (or the average of `dist_left + dist_right`)
       so the correction has units of radians per (relative error), not
       radians per cm.
     - Add a debug print of `(dist_left, dist_right, error, correction,
       new_heading)` for the first few scan cycles to test-output so we can
       see what the robot is actually doing.
     - Reconsider whether the spec's `kp = 0.5` is dimensionally consistent
       with the chosen error metric and surface that question if it is not.
4. **Confirm clean `-Wall -Wextra` build.** Spec Verification item 1 requires
   zero warnings; the build log shows no warnings but does not enable
   `-Wextra` in the CMake invocation, so this remains unverified.

Process recommendation: a third unmodified re-run of the `implement` stage is
unlikely to surface a different result. Recommend either (a) attaching a
diagnostic logging requirement to the next `implement` run so the failure mode
becomes visible in `test-output.txt`, or (b) escalating to a human to make a
gain-scale or scan-geometry decision that the spec does not pin down
unambiguously.

Non-blocking observations:

- `Action` enum relocated into `DataLogger.h` and reduced to a constant
  `FORWARD` per log entry — confirm dataset consumers tolerate this.
- R5 single-wall and no-wall branches remain unreachable in the current
  scenario suite given the `sensor_range_cm` substitution for the missing
  `wall_detection_threshold_cm`.
- Missing trailing newlines in three changed files.
