---
target_repo: volker-p/SimulationPathFinder
target_branch: master
type: feature
---

# WallFollower::update() — pass all five scenario tests

## Goal
Refine `WallFollower::update()` so that every scenario in the `--scenario-suite` run
reports **Traversal success: YES**, working through the five tests in order.

## Background
`WallFollower::update()` already uses a stop-scan-drive cycle:
stop → scan left (+90°) → scan right (−90°) → compute heading correction →
rotate to new heading → drive one step.

The scan covers only ±90° from the current heading. There is no forward scan, so the
robot cannot detect a wall or dead end directly ahead. This is likely to cause failures
on the CORNER and JUNCTION scenarios, where the robot needs to steer into an opening
before hitting the wall at the end of its current corridor.

The five deterministic scenario tests are already implemented and runnable via the
`--scenario <name>` and `--scenario-suite` CLI flags.

## Development strategy

Work through the scenarios in this exact order. Do not proceed to the next scenario
until the current one reports **Traversal success: YES**.

| # | Scenario | Grid | Start cell / heading | Goal |
|---|----------|------|----------------------|------|
| 1 | `STRAIGHT_TUNNEL` | 3×5 | (1,0) South | (1,4) |
| 2 | `CORNER_RIGHT` | 5×4 | (1,0) South | (4,2) — turns East |
| 3 | `CORNER_LEFT` | 5×4 | (3,0) South | (0,2) — turns West |
| 4 | `T_JUNCTION` | 5×5 | (2,0) South | (1,3) **or** (3,3) |
| 5 | `FOUR_WAY_CROSSING` | 5×5 | (2,0) South | (0,2), (4,2), **or** (2,4) |

**Per-scenario loop:**
1. Build: `cmake --build cmake-build-debug`
2. Run: `./cmake-build-debug/SimulationPathFinder --scenario <name>`
3. If output shows `Traversal success : YES` → move to the next scenario.
4. If not → read the metrics (collision count, steps taken, stuck?) to understand
   the failure mode, fix `WallFollower::update()`, rebuild, and repeat from step 1.
5. After each scenario turns green, re-run the full suite to check for regressions
   before moving on.

## Requirements

### R1 — Straight tunnel navigation
`update()` must navigate the 3×5 straight corridor from start to goal. Proportional
tunnel-centring (left/right wall distance error) must keep the robot centred and
driving South without getting stuck.

### R2 — Corner detection and turning
`update()` must detect when the corridor ahead ends and an opening exists to one
side, and must steer into that opening. The current ±90° scans alone are insufficient
for this; extending the scan set (e.g. adding a 0° forward scan) or adding explicit
dead-end logic is likely necessary.

### R3 — Symmetric corner handling
The mechanism that makes CORNER_RIGHT pass must generalise to CORNER_LEFT without
requiring separate special-case code for each direction.

### R4 — Junction path selection
At a T-junction or four-way crossing, `update()` must commit to one of the available
open passages and navigate the robot to a valid goal cell. Reaching **any** listed
goal cell counts as success; the robot does not need to choose a specific branch.

### R5 — No regressions
Every change must leave all already-passing scenarios still passing. Run
`--scenario-suite` after each scenario goes green.

## Files to change

| File | What changes |
|------|-------------|
| `src/WallFollower.cpp` | `update()` logic — scan angles, heading computation, corner/junction handling |
| `include/WallFollower.h` | Only if new private helpers or fields are needed |

Do not modify scenario infrastructure (`ScenarioSimulation.cpp`, `Maze.cpp`),
`config.json` default values, or any other files.

## Verification

Build and run the full suite:

```bash
cmake --build cmake-build-debug && \
  ./cmake-build-debug/SimulationPathFinder --scenario-suite
```

Expected output — all five rows must show `YES`:

```
SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS
STRAIGHT_TUNNEL       YES      ...
CORNER_RIGHT          YES      ...
CORNER_LEFT           YES      ...
T_JUNCTION            YES      ...
FOUR_WAY_CROSSING     YES      ...
```

`run-tests.sh` must assert that every scenario name line in the output contains `YES`
and print `--- TESTS PASSED ---` only after all five are confirmed.
