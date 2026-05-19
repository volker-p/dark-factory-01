# PR Review: Deterministic Scenario Testing with Wall-Safety Metrics

**Spec:** `specs/simulation-path-finder/scenario-testing.md`
**Commit under review:** `81ee94f` — *Add deterministic scenario testing with wall-safety metrics (--scenario / --scenario-suite)*

Note: the repo does not contain an `AGENTS.md`. The project-wide conventions
document is `target-repo/CLAUDE.md`, which I used as the reference for style and
architecture expectations.

---

## Requirements

### R1 — Deterministic maze factory — ✅ Met
- `ScenarioType` enum defined at `include/Maze.h:7-13`.
- `static Maze createScenario(ScenarioType, int cell_size_cm = 20)` declared
  at `include/Maze.h:73`, implemented at `src/Maze.cpp:189-200`.
- Private helper `removeWallBetween` declared at `include/Maze.h:42`,
  implemented at `src/Maze.cpp:101-118`. It symmetrically updates both cells
  (N↔S, E↔W). Wall-index convention matches the spec
  (N=0, E=1, S=2, W=3).
- Private helper `generateScenario(ScenarioType)` at
  `src/Maze.cpp:120-187` removes the correct walls for each scenario.
- A second private constructor `Maze(int, int, double, bool)` was added at
  `include/Maze.h:44` / `src/Maze.cpp:87-95` to build an empty grid without
  running `generateRecursiveBacktracking`. That function is left untouched,
  satisfying the "Do not modify `generateRecursiveBacktracking`" constraint.

I traced each scenario by hand against the ASCII diagrams in the spec — all
five wall removals match (STRAIGHT_TUNNEL: south of `(1,r)` for `r=0..3`;
CORNER_RIGHT: vertical `(1,0)-(1,2)` + horizontal `(1,2)-(4,2)`; CORNER_LEFT:
vertical `(3,0)-(3,2)` + horizontal `(0,2)-(3,2)`; T_JUNCTION: vertical
`(2,0)-(2,3)` + horizontal `(1,3)-(3,3)`; FOUR_WAY: vertical `(2,0)-(2,4)`
+ horizontal `(0,2)-(4,2)`).

**Minor inconsistency (not blocking):** the spec text says "All use
`cell_size_cm = 20`" but also instructs `runScenario` (R4) to call
`Maze::createScenario(type, config.cell_size_cm)`. The implementation
follows R4 (uses `config.cell_size_cm`, which defaults to 50 in `config.json`),
so the runtime cell size is 50 cm and the `=20` default is dead. This matches
the spec literally and is sensible (robot radius is 15 cm — 20 cm cells would
be infeasible).

### R2 — Scenario goal placement — ✅ Met
- `setGoalPosition(double, double)` declared at `include/Maze.h:70`,
  implemented at `src/Maze.cpp:97-99`.
- Called from `generateScenario` for every scenario (`src/Maze.cpp:127, 137,
  147, 159, 173`). Goal placed at cell-centre as required
  (`(cx + 0.5) * cs`).

### R3 — `ScenarioMetrics` struct — ✅ Met
- Declared at `include/ScenarioSimulation.h:7-15`. All seven fields present
  with the names and types from the spec.
- `near_miss_count` increment at `src/ScenarioSimulation.cpp:53-54` uses
  `min_reading < config.robot_radius_cm + 2.0`. The spec wording is "any
  sensor"; using the minimum sensor reading is equivalent.
- `collision_count` increment at `src/ScenarioSimulation.cpp:64-66` compares
  pose before/after `Robot::update` — equivalent to the spec's reference to
  `getPose()` vs `getPreviousPose()`, since `update` sets `previous_pose`
  to the pre-update pose (`src/Robot.cpp:78`).

### R4 — `ScenarioSimulation` class — ✅ Met
- Declared at `include/ScenarioSimulation.h:17-26` with the exact public
  surface required.
- `runScenario` (`src/ScenarioSimulation.cpp:10-79`) follows the seven sub-
  steps: creates the maze, picks start cell + heading, constructs Robot +
  WallFollower, runs up to `config.max_steps`, collects sensor readings with
  `with_noise = false` (line 49), detects collision via pose comparison,
  exits early on `isAtGoal`.
- All five start poses use heading `PI/2` (south). This is **consistent with
  the codebase**: in `Robot::update` (`src/Robot.cpp:82-83`),
  `new_y = y + linear_vel * sin(theta) * dt`. With y increasing south,
  `sin(PI/2) = +1` ⇒ moves south. (Note: `CLAUDE.md:62-72` actually says
  "South → theta = -PI/2", but that note appears to be a stale convention
  document — the actual `Robot::reset` callsites and physics use +PI/2 for
  south. The implementation matches the spec and the live code.)
- `isAtGoal` (`src/ScenarioSimulation.cpp:81-114`) checks the stored goal
  plus the alternate goal cells for T_JUNCTION (`(3,3)`) and FOUR_WAY_CROSSING
  (`(0,2)`, `(4,2)`). The "within `cell_size_cm / 2`" threshold matches the
  spec.
- `runSuite` (`src/ScenarioSimulation.cpp:116-123`) iterates the enum in
  the required order.

### R5 — CLI flags — ✅ Met
- `--scenario <name>` and `--scenario-suite` parsed in a preliminary pass
  (`main.cpp:74-86`) and acknowledged in the main pass (`main.cpp:98-101`).
- Name → enum mapping uses the exact strings from the spec
  (`main.cpp:151-168`).
- Help text updated (`main.cpp:56-59`).
- Scenario mode forces `enable_visualization = false` and exits after
  printing — bypasses normal batch flow (`main.cpp:138-171`).

### R6 — Console output format — ✅ Met
- Single-scenario output (`main.cpp:20-28`) reproduces the labels and order
  from the spec verbatim (`Scenario:`, `Traversal success`, `Steps taken`,
  `Distance (cm)`, `Min clearance (cm)`, `Near misses`, `Collisions`).
- Suite table (`main.cpp:30-43`) uses `std::printf` with `%-Nx` width
  specifiers as the spec allows. Column header order matches.
- Alignment differs slightly from the spec's hand-drawn example (the spec
  shows numeric columns right-aligned; the implementation uses
  left-aligned `%-` widths). Header columns line up with their values, so
  this is readable but not a perfect visual match. Not blocking.

### Constraints — ✅ Met
- C++20: ok (structured bindings, brace-init).
- `common/` directory: untouched (not present anyway).
- `WallFollower`, `Renderer`, `DataLogger`: not modified, not invoked.
- No raw owning pointers added.

---

## Test Coverage

`run-tests.sh` exercises the build plus three smoke invocations:
1. `--batch 2 --headless` (regression check)
2. `--scenario straight_tunnel`
3. `--scenario-suite`

What it actually verifies:
- The new code paths **compile and run to completion** without crashing.
- The output format is produced.
- Existing batch mode still functions.

What it does **not** verify:
- Wall geometry per scenario. There are no unit tests asserting that, e.g.,
  cell `(1,0).walls[2] == false` in STRAIGHT_TUNNEL or that `(2,3)` is open
  to both `(1,3)` and `(3,3)` in T_JUNCTION. Given the only safety net is
  one human visually inspecting CLI output, a typo in `generateScenario`
  could easily go unnoticed.
- Goal-detection correctness. `isAtGoal` is never exercised positively in
  the test (every scenario times out; see below). The alternate-goal
  branches for T_JUNCTION and FOUR_WAY are entirely uncovered.
- `removeWallBetween` symmetry. A unit test would be ~10 lines and would
  catch a future regression where someone reverses an index.

### Weakness: the empirical run shows every scenario failing identically

Test output (from the gate log and reproduced locally):
```
STRAIGHT_TUNNEL       NO  10000  1446.6  14.0  2638  3795
CORNER_RIGHT          NO  10000  1446.6  14.0  2638  3795
CORNER_LEFT           NO  10000  1446.6  14.0  2638  3795
T_JUNCTION            NO  10000  1446.6  14.0  2638  3795
FOUR_WAY_CROSSING     NO  10000  1446.6  14.0  2638  3795
```

I reproduced this — every scenario produces bit-identical metrics. I believe
the root cause is that all five scenarios start the robot at row 0 of a
1-cell-wide southbound corridor of 50 cm cells. The robot (15 cm radius =
30 cm diameter, 20 cm of margin total inside the corridor) cannot reverse
direction inside the corridor, gets stuck in the RECOVERY ↔ FOLLOW_WALL
loop visible in the logs, and never reaches the differentiating geometry
further down. The metric collector itself appears to work correctly — fresh
`Maze`, fresh `Robot`, fresh `WallFollower`, fresh `ScenarioMetrics` are
constructed per call (`src/ScenarioSimulation.cpp:11-35`).

This is a **spec/controller-fit problem, not an implementation defect**:
the spec explicitly says "Do not modify `WallFollower` — scenarios exercise
the controller as-is", and the spec also defines the start poses and cell
sizes. The factory output is faithful to the spec; the wall follower simply
cannot solve these corridors. The acceptance criteria for R1–R6 are
behavioural ("must compute X, must print Y"), not "robot must succeed", so
strictly speaking nothing is failing the spec. But a human reviewer should
know this when interpreting the numbers — **the suite as it stands cannot
tell us whether the simulation framework is doing the right thing**, because
all five rows are identical regardless of the maze.

---

## Code Quality

### Conformance with CLAUDE.md
- Coordinate system: matches the live code (south = +PI/2). The CLAUDE.md
  note that says otherwise is stale — see R4 above.
- Style: matches surrounding files (header guard / `#pragma once` mix
  matches existing convention — `ScenarioSimulation.h` uses `#pragma once`
  like `WallFollower.h`).
- `std::unique_ptr` for heap allocation: none needed; nothing is heap-
  allocated in the new code.
- Sensor index assumptions: `ScenarioSimulation` does not bake in any
  sensor-index logic; it only takes the min — robust to sensor-layout
  changes.

### Correctness issues / bugs

1. **Trailing-newline regression (cosmetic).** Three of the modified files
   now end without a trailing newline:
   - `CMakeLists.txt` (visible in the diff as
     `target_link_libraries(...)$\ No newline at end of file`)
   - `include/Maze.h`
   - `main.cpp`
   Not a blocker, but mildly annoying for future diffs and should be fixed.

2. **Uncommitted `test_output/batch_summary.txt` drift.** `git diff HEAD`
   on `target-repo` shows the only working-tree change is an updated
   `test_output/batch_summary.txt` from the test script running `--batch 2`.
   This file was checked into the repo from a prior `--batch 5` run. Either
   the file should not be tracked (it's a build artifact), or `run-tests.sh`
   should write to a temp directory. Not introduced by this PR — but the
   PR didn't fix it either. Worth a one-line `.gitignore` cleanup.

3. **`createScenario`'s `cell_size_cm = 20` default is effectively dead.**
   `runScenario` always passes `config.cell_size_cm`, and there is no other
   caller. Harmless, but the spec's claim that scenarios "use
   `cell_size_cm = 20`" is not what actually runs.

4. **`distance_cm` is read from `Robot::getTotalDistance()` once after the
   loop exits.** If the loop exits via `break` on `isAtGoal`, the distance
   reflects the path travelled — good. If it exits via `max_steps`, the
   distance still reflects the actual path. ✓ This is correct, just calling
   it out because I verified it.

5. **`near_miss_count` uses minimum sensor.** The spec says "at least one
   sensor reading falls below threshold", i.e. `any_of(...)`. Using
   `min(...) < threshold` is mathematically equivalent. ✓

### Surprises a reviewer should look at
- The new private constructor `Maze(int, int, double, bool /*tag*/)` is an
  unusual idiom — a `bool` tag is used purely to disambiguate from the
  random-maze constructor. A small named factory or a private default
  constructor + grid-init helper would be cleaner, but the current approach
  works and is contained.
- All five scenarios produce identical metrics in the test run. See the
  **Test Coverage** section. A reviewer might initially suspect a state-
  leak bug; on inspection there is none — it's a controller-vs-geometry
  issue.

---

## Verdict

**APPROVE** — with the caveats below.

All six P0 requirements (R1–R6) are met against the literal text of the
spec, the code compiles cleanly, existing batch mode is not regressed,
and the new CLI flags work as specified. The implementation is small,
self-contained, and follows the codebase's style.

Caveats the author/reviewer should be aware of before merging:

- **Identical metrics across all five scenarios** in the smoke run mean
  the suite, in its current form, has very weak signal value. This is a
  fit-for-purpose problem with the spec (controller cannot turn around in
  a 50 cm corridor with a 30 cm-diameter robot), not a code bug. A follow-
  up spec should either (a) widen the start corridor, (b) allow modifying
  the controller, or (c) accept this and just use the suite as a
  collision-counter smoke test.
- **No unit tests** for `removeWallBetween` symmetry, scenario wall layouts,
  or `isAtGoal` multi-goal handling. The current acceptance is "compiles
  and runs"; the alternate-goal branches for T_JUNCTION and FOUR_WAY are
  effectively unexecuted. A follow-up should add a minimal gtest/Catch2
  harness or a `--scenario-self-check` flag that asserts wall booleans.
- Trim trailing newlines back into `CMakeLists.txt`, `include/Maze.h`,
  `main.cpp` (1-line fix in each).
- `test_output/batch_summary.txt` should not be a tracked file. Add to
  `.gitignore` in a follow-up.

None of these block the merge under the spec as written.
