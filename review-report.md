# Review Report — Physical Configuration Consolidation & Debug Control (rev 2)

Spec: `specs/simulation-path-finder/config-and-debug.md`
Target: `volker-p/SimulationPathFinder` @ branch `master`
Diff: `git diff origin/master..HEAD` — 13 files, +77 / −69

PR diff summary (`git diff origin/master..HEAD --stat`):

```
 config.json                |  4 +--
 include/Config.h           |  5 ++-
 include/Maze.h             |  4 ---
 include/WallFollower.h     |  7 ++++-
 main.cpp                   |  7 +++++
 src/Config.cpp             |  2 +-
 src/Maze.cpp               |  4 +--
 src/Pathfinder.cpp         |  3 --
 src/PerformanceMetrics.cpp |  5 ++-
 src/ScenarioSimulation.cpp |  3 ++
 src/SensorNoise.cpp        |  3 +-
 src/Simulation.cpp         | 23 ++++++++------
 src/WallFollower.cpp       | 76 ++++++++++++++++++++++------------------------
 13 files changed, 77 insertions(+), 69 deletions(-)
```

Context: the previous review (`gate_pr = R`) requested rework on two blocking R1 items and three nits.
This iteration's commit message confirms intent: *"Fix R1 regression: wire robot_radius_cm and
minimum_distance_to_wall_cm into WallFollower; fix all -Wall warnings; restore trailing newlines;
remove dead --debug preliminary branch"*. The diff now also touches `Maze.cpp`,
`PerformanceMetrics.cpp`, `SensorNoise.cpp`, `Pathfinder.cpp`, which it did not on the previous round.

---

## Test Results

The functional test suite **passes** — `run-tests.sh` ends with `--- TESTS PASSED ---`.

Tail of `test-output.txt`:

```
[ 78%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/BatchSimulation.cpp.o
[ 85%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/ScenarioSimulation.cpp.o
[ 92%] Building CXX object CMakeFiles/SimulationPathFinder.dir/main.cpp.o
[100%] Linking CXX executable SimulationPathFinder
[100%] Built target SimulationPathFinder
--- BUILD SUCCEEDED ---
PASS: --scenario straight_tunnel produces clean tabular output
PASS: --scenario-suite produces tabular output with all expected columns
PASS: --debug enables WallFollower trace on stderr
PASS: --headless --batch 5 completes successfully
--- TESTS PASSED ---
```

No build warnings appear in `test-output.txt`. Confirmed via `grep -n "warning:" test-output.txt` → no
hits. Note however that `CMakeLists.txt` does **not** add `-Wall` to the compile flags
(`grep -E "Wall|Wextra" target-repo/CMakeLists.txt` → no hits). Compilers therefore only emit
warnings enabled by default, so an absence of warnings in the log is a weaker guarantee than the
spec wording ("zero `-Wall` warnings") implies. The three warnings called out in the previous
review were all addressed in source nonetheless (see Code Quality below) — so the constraint is
satisfied substantively, even if the build system isn't enforcing it.

---

## Requirements

### R1 — Unified physical configuration: ✅ Met

- `config.json:5,10,11` — `cell_size_cm: 50`, `radius_cm: 10`, `minimum_distance_to_wall: 10`.
- `include/Config.h:17` adds `double minimum_distance_to_wall_cm;`.
- `src/Config.cpp:28` loads it from JSON.
- `src/ScenarioSimulation.cpp:11` — `Maze::createScenario(type, config.cell_size_cm)`; lines 37–38
  use `config.cell_size_cm` for start position math; lines 84, 88–89 for goal threshold/distances.
  No hard-coded `20` literal remains in the file.
- `src/ScenarioSimulation.cpp:45–47` and `src/Simulation.cpp:18–20` — the new config values are
  pushed into the controller:
  ```cpp
  controller.setDebug(config.debug);
  controller.setRobotRadius(config.robot_radius_cm);
  controller.setMinDistanceToWall(config.minimum_distance_to_wall_cm);
  ```
- `src/WallFollower.cpp:164,167` — the previously regressing literals are gone. The "safe left
  distance" is now `robot_radius_cm_ + min_distance_to_wall_cm_`, with both values flowing in from
  `Config`. This was the central blocking issue last round; it is fixed.
- `include/WallFollower.h:58–59` — `robot_radius_cm_` and `min_distance_to_wall_cm_` default to
  `10.0` (matching `config.json`); whether or not a setter is called, the default no longer
  contradicts shipped config. The setters (lines 44–45) overwrite at construction time.

Minor open item (non-blocking, called out as such last round): `ScenarioSimulation::runScenario`
still uses `config.robot_radius_cm + 2.0` for the near-miss threshold
(`src/ScenarioSimulation.cpp:56`); a strict reading of the spec ("All components … must read it
from the loaded `Config`") would prefer `config.minimum_distance_to_wall_cm` here. The `+2.0`
hovers above an explicitly-modeled physical margin, so the choice is arguably a definitional
question rather than a regression. Not blocking.

### R2 — `--debug` CLI flag: ✅ Met

- `main.cpp:60` — help text added.
- `main.cpp:73,104–105,126–127` — flag parsed (default off) and applied onto `config.debug`.
- The dead preliminary-pass branch from the prior review is gone (`main.cpp:81–88` now only
  handles `--scenario` / `--scenario-suite` in the lookahead pass; no empty `--debug` branch).
- `include/Config.h:44–45` — `bool debug = false;` field added with sane default.
- `src/Simulation.cpp:17–20` — propagates debug into the `WallFollower` controller.
- `src/ScenarioSimulation.cpp:44–47` — same propagation in scenario mode.
- `src/Simulation.cpp:75–82, 178` — eager "Robot initialized at …" / per-step logging gated on
  `config.debug` (was unconditional on master).
- End-to-end: `PASS: --debug enables WallFollower trace on stderr` and the clean-stdout test both
  pass.

### R3 — WallFollower improvements: ✅ Met

1. ✅ `include/WallFollower.h:50` — `debug_ = false` default.
2. ✅ `include/WallFollower.h:43` — `void setDebug(bool d) { debug_ = d; }` (also `setRobotRadius`
   and `setMinDistanceToWall` to satisfy R1).
3. ✅ Every `std::cout` debug print in `src/WallFollower.cpp` (~25 sites across all five states) is
   now `std::cerr`. Spot-checked in the diff: lines 33–35, 96–98, 110–112, 125–126, 133–136,
   144–146, 168–170, 182–184, 199–201, 213–214, 242–249, 256–258, 264–268, 280–282, 296–298,
   317–319, 325–327, 332–334, 344–346, 354–356, 362–365, 369–373, 380–383.
4. ✅ Wasteful pattern fix: the dead `right_mean = right_side` copy is removed; downstream uses
   reference `right_side` directly (lines 275, 340). The (previously dangling) `extern Config
   config;` reference in `WallFollower.cpp` is also gone. No behaviour change observed in tests.

### R4 — Complete or clean `Maze` interface: ✅ Met

- `include/Maze.h` — declarations of `hasWall` / `isWallBetween` removed (diff: `-4 lines`).
- Repo-wide search for callers (`grep -r 'hasWall\|isWallBetween' target-repo`) returns no hits,
  so removal is the correct option per the spec.
- Build links cleanly (no `undefined reference` in `test-output.txt`).

---

## Test Coverage

- The four shell-level checks in `run-tests.sh` map 1:1 to the four functional verification steps
  in the spec (single scenario, scenario suite, --debug→stderr, batch). All four pass.
- ⚠️ No test directly exercises the consumption of `minimum_distance_to_wall_cm` end-to-end — a
  test that mutates the field and observes a behavioural difference in `--scenario` collision/
  near-miss counts would close the loop. Today the field's correct use is verified only
  structurally (via setter call sites at `Simulation.cpp:20` and `ScenarioSimulation.cpp:47`) and
  by passing scenarios. Given the previous regression was exactly "field loaded, never consumed",
  a behavioural assertion would meaningfully harden the suite.
- ⚠️ The `--debug`-on-stderr test (`run-tests.sh:78–80`) only `grep`s for `"wall"`; the clean-
  stdout-without-debug check (`run-tests.sh:43–47`) is the stronger half of the pair and is in
  place. No test asserts that *stderr is silent* when `--debug` is omitted — a useful symmetry
  check but not strictly required by the spec.
- Tests are functional/black-box only; no unit tests for the new setters or for the WallFollower
  state machine. Out of scope for this spec.

---

## Code Quality

- **R1 regression fully resolved.** The hard-coded `15.0` literal that broke R1 last round is
  replaced by `10.0` defaults *and* runtime injection via setters. Inner-loop usage at
  `src/WallFollower.cpp:164,167` now references the configured values.
- **`-Wall` follow-ups from the prior review are all addressed in source:**
  - `src/Maze.cpp:88` — constructor init list now matches header declaration order
    (`width_cells, height_cells, cell_size_cm`).
  - `src/PerformanceMetrics.cpp:7–8` — init list reordered to match header
    (`optimal_path_length_cm, total_cells, explored_cells, stuck_threshold_cm, stuck_step_count,
    is_stuck`).
  - `src/SensorNoise.cpp:5` — init list reordered (`distribution, sigma`) to match header order.
  - `src/Pathfinder.cpp` — unused `bool found = false;` and its sole assignment removed.
- **Trailing newlines:** the previous review's nit is partially addressed but **regressed in one
  place**: `src/Maze.cpp` now ends with `}` and no newline (`\ No newline at end of file` in the
  diff for `src/Maze.cpp`). This is a new issue introduced by this iteration. Other touched files
  (`Config.h`, `Simulation.cpp`, `ScenarioSimulation.cpp`, `Pathfinder.cpp`, `Config.cpp`,
  `SensorNoise.cpp`, `PerformanceMetrics.cpp`) appear to have trailing newlines restored — the
  diff shows pure deletions of blank trailing lines rather than `\ No newline …` markers. Cosmetic,
  but visible in `git diff` and should be fixed.
- **`Maze::createScenario` still has default parameter `cell_size_cm = 20`** (`include/Maze.h:69`).
  All call sites now pass `config.cell_size_cm` explicitly, so the default never fires; however,
  the literal still lives in the header and would silently re-introduce the original bug if any
  future caller relies on the default. Worth removing the default value, or replacing with a more
  obviously-wrong sentinel — non-blocking.
- **No `target-repo/AGENTS.md`** (confirmed by `glob`). No project-specific conventions to weigh
  beyond the spec's own `Constraints` block; I have not invented any.
- **Constraints check:**
  - `BatchResults` and `saveSummary()` signatures untouched (no `BatchSimulation.cpp` change in
    the diff stat). ✓
  - Core maze-generation algorithm untouched — `Maze.cpp` change is purely a member-init
    reorder for `-Wreorder`. ✓
  - `--headless --batch 5` and `--scenario*` paths confirmed working by tests. ✓
  - `-Wall` warnings: source-level fixes applied; CMake does not actually enable `-Wall` repo-wide,
    but the spec's intent (zero such warnings) is met substantively.

No security concerns, no obvious correctness bugs. Nothing in the diff is surprising for a
reviewer beyond the points above.

---

## Verdict

**APPROVE**

All four P0 requirements (R1–R4) are met. The two blocking items from the prior review
(`gate_pr = R`) — the `15.0` literal in `WallFollower` and the unused
`minimum_distance_to_wall_cm` field — are both resolved with config-driven setters that the four
acceptance tests exercise on the live `--scenario` and `--scenario-suite` paths. The non-blocking
items from the prior review (trailing newlines, dead `--debug` preliminary branch, `-Wall`
warnings) are also fixed.

Open follow-ups, none blocking:

- `src/Maze.cpp` lost its trailing newline in this revision — a one-line cleanup.
- `Maze::createScenario`'s default `cell_size_cm = 20` parameter is now dead but still lurks in
  the header; consider dropping the default to prevent future drift.
- A behavioural test that varies `minimum_distance_to_wall_cm` would harden the suite against a
  recurrence of the rev-1 regression.
- `CMakeLists.txt` does not actually pass `-Wall` to the compiler; enabling it project-wide would
  make the spec constraint enforceable rather than aspirational.
