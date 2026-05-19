---
target_repo: volker-p/SimulationPathFinder
target_branch: master
type: feature
---

# Deterministic Scenario Testing with Wall-Safety Metrics

## Goal

Add a suite of five hand-crafted maze scenarios (straight tunnel, corner-right,
corner-left, T-junction, four-way crossing) and a per-scenario safety report that
measures how close the robot comes to walls and whether it traverses each
scenario without getting blocked or colliding.

---

## Background

The existing simulation generates mazes randomly using recursive backtracking
(`Maze::generateRecursiveBacktracking`).  Random mazes are useful for batch
statistics but make it impossible to reproduce and analyse specific robot
behaviours.  Deterministic scenarios give a fixed, human-readable test
environment: if wall-following regresses, a specific scenario will reveal it.

---

## Requirements

### R1 — Deterministic maze factory

Add a static factory method to `Maze`:

```cpp
static Maze createScenario(ScenarioType type, int cell_size_cm = 20);
```

`ScenarioType` is an enum class defined in `Maze.h`:

```cpp
enum class ScenarioType {
    STRAIGHT_TUNNEL,
    CORNER_RIGHT,
    CORNER_LEFT,
    T_JUNCTION,
    FOUR_WAY_CROSSING
};
```

Each scenario is a small maze (≤ 7 × 7 cells) where specific inter-cell walls
are removed to form the desired geometry.  All other walls remain intact
(each `Cell` starts with all four walls `true`, as per the existing constructor).

To remove a wall between adjacent cells `(x1, y1)` and `(x2, y2)`, add a
private helper:

```cpp
void removeWallBetween(int x1, int y1, int x2, int y2);
```

It must update both cells symmetrically (e.g. removing the South wall of
`(x,y)` also removes the North wall of `(x, y+1)`).

**Do not modify `generateRecursiveBacktracking`.** The factory method calls a
new private `void generateScenario(ScenarioType type)` instead.

Wall directions: `walls[0]` = North, `walls[1]` = East, `walls[2]` = South,
`walls[3]` = West.  Axes: x increases East, y increases South (row 0 is the
northernmost row).

#### Scenario geometries

All use `cell_size_cm = 20`.  `S` = start cell, `G` = goal cell.

**STRAIGHT_TUNNEL** — 3 × 5 cells (W × H).  A single corridor along the
centre column.

```
col:  0   1   2
row 0: [#] [S] [#]
row 1: [#] [ ] [#]
row 2: [#] [ ] [#]
row 3: [#] [ ] [#]
row 4: [#] [G] [#]
```

Remove the South wall of `(1, r)` and the North wall of `(1, r+1)` for
`r = 0..3`.  All cells in columns 0 and 2 keep all four walls
(they are unreachable dead ends that form the outer corridor walls).

Start pose: centre of cell `(1, 0)`, heading South (θ = π/2).
Goal cell: `(1, 4)`.

---

**CORNER_RIGHT** — 5 × 4 cells.  Enter from the North, turn East.

```
col:  0   1   2   3   4
row 0: [#] [S] [#] [#] [#]
row 1: [#] [ ] [#] [#] [#]
row 2: [#] [ ] [ ] [ ] [G]
row 3: [#] [#] [#] [#] [#]
```

Vertical segment: remove walls between `(1,0)-(1,1)-(1,2)` (South of each
upper cell, North of each lower cell).
Horizontal segment: remove walls between `(1,2)-(2,2)-(3,2)-(4,2)` (East of
each left cell, West of each right cell).

Start pose: centre of `(1, 0)`, heading South.
Goal cell: `(4, 2)`.

---

**CORNER_LEFT** — 5 × 4 cells.  Enter from the North, turn West.

```
col:  0   1   2   3   4
row 0: [#] [#] [#] [S] [#]
row 1: [#] [#] [#] [ ] [#]
row 2: [G] [ ] [ ] [ ] [#]
row 3: [#] [#] [#] [#] [#]
```

Vertical segment: remove walls between `(3,0)-(3,1)-(3,2)`.
Horizontal segment: remove walls between `(0,2)-(1,2)-(2,2)-(3,2)`.

Start pose: centre of `(3, 0)`, heading South.
Goal cell: `(0, 2)`.

---

**T_JUNCTION** — 5 × 5 cells.  Enter from the North, reach a T.

```
col:  0   1   2   3   4
row 0: [#] [#] [S] [#] [#]
row 1: [#] [#] [ ] [#] [#]
row 2: [#] [#] [ ] [#] [#]
row 3: [#] [G] [ ] [G] [#]    ← two possible goal cells
row 4: [#] [#] [#] [#] [#]
```

Vertical segment: remove walls between `(2,0)-(2,1)-(2,2)-(2,3)`.
Horizontal segment: remove walls between `(1,3)-(2,3)-(3,3)`.

Start pose: centre of `(2, 0)`, heading South.
Goal cells: `(1, 3)` **or** `(3, 3)` — traversal succeeds if the robot
reaches either one.

---

**FOUR_WAY_CROSSING** — 5 × 5 cells.  Enter from the North, cross through
the centre.

```
col:  0   1   2   3   4
row 0: [#] [#] [S] [#] [#]
row 1: [#] [#] [ ] [#] [#]
row 2: [G] [ ] [ ] [ ] [G]
row 3: [#] [#] [ ] [#] [#]
row 4: [#] [#] [G] [#] [#]
```

Vertical segment: remove walls between `(2,0)-(2,1)-(2,2)-(2,3)-(2,4)`.
Horizontal segment: remove walls between `(0,2)-(1,2)-(2,2)-(3,2)-(4,2)`.

Start pose: centre of `(2, 0)`, heading South.
Goal cells: any of `(0,2)`, `(4,2)`, `(2,4)`.

---

### R2 — Scenario goal placement

`Maze::createScenario` must call `maze.goal_position` (or `setGoalPosition`) to
place the goal at the centre of the designated goal cell.  Add a setter:

```cpp
void setGoalPosition(double x_cm, double y_cm);
```

---

### R3 — ScenarioMetrics struct

Add `include/ScenarioSimulation.h` declaring:

```cpp
struct ScenarioMetrics {
    ScenarioType    scenario;
    bool            traversal_success;   // reached goal cell without getting stuck
    int             steps_taken;         // simulation steps until success or max_steps
    double          distance_cm;         // total distance travelled by robot
    double          min_clearance_cm;    // minimum sensor reading across all steps
    int             near_miss_count;     // steps where any sensor < robot_radius_cm + 2.0
    int             collision_count;     // steps where checkCollision returned true
                                         // (robot position did not advance)
};
```

`near_miss_count` counts individual simulation steps (not collisions) where at
least one sensor reading falls below `robot_radius_cm + 2.0 cm`.

`collision_count` counts steps where the robot attempted to move but its
position did not change (i.e. `Robot::getPose()` equals `Robot::getPreviousPose()`
after `update()`).

---

### R4 — ScenarioSimulation class

In the same header, declare:

```cpp
class ScenarioSimulation {
public:
    explicit ScenarioSimulation(const Config& cfg);

    ScenarioMetrics runScenario(ScenarioType type);
    std::vector<ScenarioMetrics> runSuite();   // all five scenarios in order

private:
    Config config;
    bool isAtGoal(const Maze& maze, const Robot& robot, ScenarioType type) const;
};
```

`runScenario` must:
1. Call `Maze::createScenario(type, config.cell_size_cm)` to get the maze.
2. Place the robot at the scenario's designated start pose (centre of start
   cell, correct heading).
3. Run headlessly up to `config.max_steps` steps using the existing
   `WallFollower` controller.
4. After each step collect sensor readings (`Robot::getSensorReadings` with
   `with_noise = false`) to update `min_clearance_cm` and `near_miss_count`.
5. Detect collision when robot pose is identical before and after `update()`.
6. Stop early if `isAtGoal()` returns true (robot centre within
   `cell_size_cm / 2` of the goal position).
7. Return the filled `ScenarioMetrics`.

`runSuite` calls `runScenario` for each of the five `ScenarioType` values.

---

### R5 — CLI flags

In `main.cpp`, parse two new flags before the existing argument handling:

| Flag | Behaviour |
|---|---|
| `--scenario <name>` | Run one named scenario and print its metrics. Valid names: `straight_tunnel`, `corner_right`, `corner_left`, `t_junction`, `four_way_crossing`. |
| `--scenario-suite` | Run all five scenarios and print a summary table. |

Both flags load `Config` from the usual config file (or defaults) but **bypass**
the existing maze generation and batch logic.  The simulation exits after
printing the report.

---

### R6 — Console output format

Single scenario (`--scenario`):

```
Scenario: CORNER_RIGHT
  Traversal success : YES
  Steps taken       : 342
  Distance (cm)     : 127.4
  Min clearance (cm): 3.2
  Near misses       : 7
  Collisions        : 0
```

Suite (`--scenario-suite`):

```
SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS
STRAIGHT_TUNNEL       YES        287     106.8      4.1        3           0
CORNER_RIGHT          YES        342     127.4      3.2        7           0
CORNER_LEFT           YES        331     124.9      3.5        5           0
T_JUNCTION            YES        398     148.2      2.9       11           0
FOUR_WAY_CROSSING     YES        445     166.1      2.7       14           1
```

Use `std::printf` or `std::cout` with `std::setw` for alignment; no external
formatting library.

---

## Constraints

- All new C++ code is C++20, matches the style of existing files (no raw
  owning pointers, use `std::unique_ptr` where heap allocation is needed).
- Do not modify `common/` (the shared C algorithm); scenario logic lives
  entirely in the C++ layer.
- No floating-point arithmetic in `common/`; the existing prohibition stands.
- Do not modify `WallFollower` — scenarios exercise the controller as-is.
- `Renderer` is not invoked for scenario runs (headless only).
- `DataLogger` is not invoked for scenario runs.

## Files to add / modify

| File | Change |
|---|---|
| `include/Maze.h` | Add `ScenarioType` enum, `createScenario`, `setGoalPosition`, `removeWallBetween` declarations |
| `src/Maze.cpp` | Implement `createScenario`, `generateScenario`, `removeWallBetween`, `setGoalPosition` |
| `include/ScenarioSimulation.h` | New file: `ScenarioMetrics`, `ScenarioSimulation` |
| `src/ScenarioSimulation.cpp` | New file: full implementation |
| `src/main.cpp` | Parse `--scenario` / `--scenario-suite`, invoke `ScenarioSimulation` |
| `CMakeLists.txt` | Add `src/ScenarioSimulation.cpp` to the build target |
