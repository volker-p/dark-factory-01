# PR Review (Round 2): Deterministic Scenario Testing with Wall-Safety Metrics

**Spec:** `specs/simulation-path-finder/scenario-testing.md`
**Commit under review:** `81ee94f` — *Add deterministic scenario testing with wall-safety metrics (--scenario / --scenario-suite)*
**Prior gate:** `gate_pr` → **Rework** (despite the prior review recommending APPROVE).

Note: `target-repo/AGENTS.md` does not exist; this repo's conventions doc is
`target-repo/CLAUDE.md`. I used that as the style/architecture reference.

## State of this review round

The "implement" and "test" stages ran again after the rework signal, but the
target-repo HEAD is **still the same commit (`81ee94f`)** that was reviewed
last round. `git log 81ee94f..HEAD` is empty. The only working-tree change is
an unrelated artifact churn in `test_output/batch_summary.txt`. **Nothing in
the implementation has actually changed since the previous rework gate.** I
reviewed the diff again from scratch below.

---

## Requirements

### R1 — Deterministic maze factory — ✅ Met
- `ScenarioType` enum at `include/Maze.h:7-13`.
- `static Maze createScenario(ScenarioType, int cell_size_cm = 20)` declared
  at `include/Maze.h:73`, implemented at `src/Maze.cpp:189-200`.
- `void removeWallBetween(int,int,int,int)` declared at `include/Maze.h:42`,
  implemented at `src/Maze.cpp:101-118`. Indices follow the spec
  (N=0, E=1, S=2, W=3) and symmetric updates are correct for all four
  cardinal directions.
- `void generateScenario(ScenarioType)` at `src/Maze.cpp:120-187` removes
  the walls required by each scenario.
- A second private constructor `Maze(int, int, double, bool)`
  (`src/Maze.cpp:87-95`) builds an empty grid without calling
  `generateRecursiveBacktracking`, which is left untouched as required.

I hand-traced each scenario against the ASCII diagrams; all five layouts
match the spec exactly.

### R2 — Scenario goal placement — ✅ Met
- `setGoalPosition(double,double)` declared `include/Maze.h:70`, implemented
  `src/Maze.cpp:97-99`.
- Called from `generateScenario` for every scenario; goal placed at cell
  centre `(cx + 0.5) * cs, (cy + 0.5) * cs`.

### R3 — `ScenarioMetrics` struct — ✅ Met
- Declared at `include/ScenarioSimulation.h:7-15`. All seven fields present
  with the spec's names and types.
- `near_miss_count` increments when `min(readings) < robot_radius_cm + 2.0`
  (`src/ScenarioSimulation.cpp:53-54`); equivalent to the spec's "any
  sensor < threshold".
- `collision_count` increments when `before == after` pose after `update()`
  (`src/ScenarioSimulation.cpp:64-66`). The spec describes this via
  `getPose()` / `getPreviousPose()`; the implementation compares pose
  before/after `update()` instead. `Robot::update` does store
  `previous_pose` (see `include/Robot.h:21, 44`), so the two are
  equivalent.

### R4 — `ScenarioSimulation` class — ✅ Met
- Declared `include/ScenarioSimulation.h:17-26` with the exact public surface
  required.
- `runScenario` (`src/ScenarioSimulation.cpp:10-79`) follows all seven
  sub-steps. Sensor readings use `with_noise = false`
  (`src/ScenarioSimulation.cpp:49`).
- All five start headings are `+PI/2`. In `Robot::update`,
  `new_y = y + linear_vel * sin(theta) * dt`; with y increasing south,
  `sin(+PI/2) = 1` moves south. This is **opposite to the convention
  documented in `CLAUDE.md:64`** ("`theta = -PI/2` → South"), but the
  implementation matches the live physics in `Robot.cpp`, not the stale
  doc, so it is correct.
- `isAtGoal` (`src/ScenarioSimulation.cpp:81-114`) checks the stored goal
  plus alternates: `(3,3)` for T_JUNCTION, `(0,2)` and `(4,2)` for
  FOUR_WAY_CROSSING. Threshold is `cell_size_cm / 2`, matching the spec.
- `runSuite` (`src/ScenarioSimulation.cpp:116-123`) iterates the five enum
  values in order.

### R5 — CLI flags — ✅ Met
- Pre-pass detects `--scenario <name>` / `--scenario-suite`
  (`main.cpp:74-86`); main pass acknowledges them as consumed
  (`main.cpp:98-101`).
- String → enum mapping uses the exact names from the spec
  (`main.cpp:151-168`). Unknown names produce an error and exit 1.
- Scenario mode forces `enable_visualization = false` and exits after
  printing — bypasses batch flow (`main.cpp:138-171`).

### R6 — Console output format — ⚠️ Partial
- Single-scenario output (`main.cpp:20-28`) matches the labels and order
  in the spec exactly.
- Suite table (`main.cpp:30-43`) prints the required columns in the
  required order. **However**, the implementation uses `%-N` (left-aligned)
  width specifiers for the numeric columns; the spec's example has the
  numeric columns right-aligned (`287`, `106.8`, `4.1`, …). This is a
  cosmetic deviation; values are readable and aligned with their headers,
  but it does not look like the spec's example. The spec says "Use
  `std::printf` or `std::cout` with `std::setw` for alignment", which is
  satisfied. Marking ⚠️ for cosmetic mismatch only.

### Constraints — ✅ Met
- C++20 features (structured bindings, brace-init) are already used in the
  repo.
- `common/` directory: not present and not touched.
- `WallFollower`, `Renderer`, `DataLogger`: not modified and not invoked
  by the scenario path.
- No raw owning pointers added.

---

## Test Coverage

`run-tests.sh` builds the project and runs three smoke invocations:

1. `--batch 2 --headless` (regression for existing pipeline).
2. `--scenario straight_tunnel`.
3. `--scenario-suite`.

What is actually verified:
- The new code paths **compile and run to completion** without crashing.
- The suite-table output is produced for all five scenarios.
- Existing batch mode still functions and writes its summary.

What is **not** verified:

1. **Wall geometry per scenario.** No unit test asserts e.g.
   `grid[0][1].walls[2] == false` (south wall of `(1,0)` removed in
   STRAIGHT_TUNNEL) or that `(2,3)` is open both west and east in
   T_JUNCTION. A single transposition in `removeWallBetween` indices
   (or a copy/paste mistake in `generateScenario`) could ship undetected.
2. **`removeWallBetween` symmetry.** A ~10-line gtest case covering all
   four directions would be both easy and high-value.
3. **`isAtGoal` correctness.** The alternate-goal branches for T_JUNCTION
   and FOUR_WAY_CROSSING are completely uncovered — see the empirical
   point below: every scenario in the smoke run times out at
   `max_steps = 10000`, so `isAtGoal` returning `true` is never exercised.

### The smoke run gives every scenario identical metrics — that is the rework signal

The test output is repeated below verbatim:

```
SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS
STRAIGHT_TUNNEL       NO       10000   1446.6    14.0     2638       3795
CORNER_RIGHT          NO       10000   1446.6    14.0     2638       3795
CORNER_LEFT           NO       10000   1446.6    14.0     2638       3795
T_JUNCTION            NO       10000   1446.6    14.0     2638       3795
FOUR_WAY_CROSSING     NO       10000   1446.6    14.0     2638       3795
```

Five mazes of three different sizes, three different wall layouts, three
different goal placements — and **bit-identical** step counts, distances,
clearances, near-misses, and collisions. That is not plausible for a
healthy implementation. Two possibilities:

- **(a) Cross-scenario state leak.** Each scenario constructs a fresh
  `Maze`, `Robot`, `WallFollower`, and `ScenarioMetrics`
  (`src/ScenarioSimulation.cpp:11-35`), so there is no obvious leak. ✓
  on inspection.
- **(b) The robot never escapes its starting cell**, so the runs only
  exercise behaviour inside cell `(start_x, start_y)`, which is structurally
  identical across all five scenarios (a 1-cell-wide southbound corridor
  with walls east and west). All five scenarios start the robot at the
  north end of a corridor that is 50 cm wide (`config.cell_size_cm` =
  50) with a 15 cm-radius robot (`config.robot_radius_cm` = 15). That
  leaves 20 cm of clearance on each side. `WallFollower`'s `FOLLOW_WALL`
  target wall-distance is 26.5 cm (per `CLAUDE.md:100`), which exceeds
  the 20 cm available — the controller can never reach its setpoint and
  oscillates between RECOVERY and FOLLOW_WALL. The log spam in the test
  output (`STUCK DETECTED`, `RECOVERY BLOCKED`, "Robot trapped in
  corner") confirms this.

The implementation faithfully encodes the spec; the spec says "exercise
the controller as-is" and "do not modify `WallFollower`". The result is
that the suite as specified provides effectively zero diagnostic signal:
**you cannot tell from the output of `--scenario-suite` whether the maze
factory, the start-pose mapping, or the goal-detection logic is correct**,
because every row of the table is the same regardless of those.

This is the most likely reason the prior `gate_pr` was a Rework. The code
satisfies R1–R6 literally, but the feature does not satisfy its **stated
goal** ("if wall-following regresses, a specific scenario will reveal
it"). With identical metrics across all five scenarios, the suite cannot
reveal regressions in *any* of them.

A minimal fix that stays within the spec's letter:

- The spec specifies `cell_size_cm = 20` (R1, "Scenario geometries: All
  use `cell_size_cm = 20`"). The implementation actually runs with
  `config.cell_size_cm` (= 50 from `config.json`). The spec's R4 step 1
  says "`Maze::createScenario(type, config.cell_size_cm)`", which the
  implementation follows. Those two statements are contradictory; the
  implementation chose R4. **But a 20 cm cell is even worse for a 15 cm
  radius robot**, so falling back to 20 wouldn't help.
- The real fix is to use a cell size that is at least 2 × (outer wall
  target) ≈ 60-70 cm so the controller can actually follow walls. That
  means either reinterpreting the spec, or asking for clarification.

Either way, *signing off on a suite where all five rows are identical
forfeits the entire diagnostic value of the feature.*

---

## Code Quality

### Conformance with CLAUDE.md
- Coordinate system: matches live physics (`sin(theta)` ⇒ south at
  `+PI/2`). CLAUDE.md's claim that south is `-PI/2` is stale; the
  implementation correctly follows the actual `Robot::update` code.
- Style and header conventions: `ScenarioSimulation.h` uses `#pragma once`
  to match `WallFollower.h`; other includes match repo convention.
- No raw owning pointers, no heap allocation needed or added.
- Sensor index assumptions: `ScenarioSimulation` does not hard-code sensor
  indices; it just takes `min_element`. Robust to sensor layout changes.

### Correctness / hygiene

1. **Missing trailing newlines** in `CMakeLists.txt`, `include/Maze.h`,
   and `main.cpp` (visible as `\ No newline at end of file` in the diff
   for all three). Cosmetic but noisy in future diffs. ⚠️
2. **`test_output/batch_summary.txt` is checked in and rewritten on every
   test run.** `git status` on the working tree currently shows this file
   as the only diff. Either `.gitignore` it or have `run-tests.sh` write
   to a temp directory. Not introduced by this PR but worth fixing while
   we are here.
3. **`createScenario`'s `cell_size_cm = 20` default is dead.** Only
   `runScenario` calls it, and it always passes `config.cell_size_cm`.
   Harmless but inconsistent with the spec's claim that scenarios "use
   `cell_size_cm = 20`".
4. **Awkward "tag" constructor.**
   `Maze::Maze(int, int, double, bool /*tag*/)` exists purely to
   disambiguate from the random-maze ctor. A named static helper
   (`static Maze makeEmpty(int,int,double)`) would be clearer. Not
   blocking.
5. **Suite-table alignment.** Numeric columns are left-justified
   (`%-Nd`, `%-N.1f`) where the spec example shows them
   right-justified. Cosmetic.

### Surprises a reviewer should look at
- **All five rows of `--scenario-suite` are bit-identical.** This is the
  single most important observation in this review. See the test-coverage
  section.
- The new private "tag" constructor for `Maze`.
- Stale CLAUDE.md note about south = `-PI/2`; resolved correctly in code.

---

## Verdict

**REQUEST CHANGES**

The code mechanically satisfies R1–R6 of the spec, and the previous round
of review noted as much. But the human gate flagged Rework, and the
**implementation has not changed since that gate** (still commit
`81ee94f`). On re-examination, the smoke-test output makes the rework
signal unambiguous:

> Five scenarios with three different maze sizes, three different layouts,
> and three different goal positions produce **bit-identical metrics
> (10000 / 1446.6 / 14.0 / 2638 / 3795)**, with `traversal_success = NO`
> in every row.

That output, by itself, demonstrates that the feature does not deliver
its stated goal ("if wall-following regresses, a specific scenario will
reveal it"). The suite cannot distinguish between the scenarios it
defines.

### Blocking items that must be addressed before merge

1. **Make the suite actually distinguish between scenarios.** Pick one
   of the following:
   - **Use a cell size large enough for the controller** (≥ 60 cm),
     either by ignoring the spec's `cell_size_cm = 20` example and
     overriding `config.cell_size_cm` for scenario runs, or by adding
     a `--scenario-cell-size <cm>` flag. Document the choice.
   - **Verify, and report if appropriate, that the failure is in the
     controller, not the scaffolding.** If the conclusion is "the
     controller cannot solve any 1-cell-wide corridor with the current
     wall-following setpoints", say so in the PR description and add a
     follow-up issue. Even then, the suite numbers should not all be
     identical — at minimum, the goal-detection paths for T_JUNCTION
     and FOUR_WAY_CROSSING should be exercised by a positive unit
     test (point-the-robot-at-the-goal test).
   - **Add at least one positive end-to-end success.** Place the robot
     within `cell_size_cm/2` of the goal in a unit/integration test
     and assert `runScenario` reports `traversal_success = true`,
     `collision_count = 0`, etc. Without this, `isAtGoal` is entirely
     untested.

2. **Add minimal unit coverage** for the new factory:
   - `removeWallBetween` symmetry in all four directions.
   - For each `ScenarioType`, assert that a small set of specific
     walls are present/absent (`assert(grid[0][1].walls[2] == false)`,
     etc.). 30 lines, catches future regressions.

3. **Fix the trailing-newline regressions** in `CMakeLists.txt`,
   `include/Maze.h`, and `main.cpp`.

### Non-blocking follow-ups
- `.gitignore` `test_output/batch_summary.txt` (or write to tmp).
- Replace the bool-tag `Maze` constructor with a named static helper.
- Right-justify numeric columns in the suite table to match the spec
  example.
- Resolve the spec contradiction between R1 ("All use `cell_size_cm =
  20`") and R4 (uses `config.cell_size_cm`) in a follow-up spec
  amendment.
