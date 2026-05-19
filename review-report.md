# Review Report — Physical Configuration Consolidation & Debug Control

Spec: `specs/simulation-path-finder/config-and-debug.md`
Target: `volker-p/SimulationPathFinder` @ branch `master`
Diff: `git diff origin/master..HEAD` — 9 files, +70 / −62

PR diff summary (`git diff origin/master..HEAD --stat`):

```
 config.json                |  4 +--
 include/Config.h           |  7 +++--
 include/Maze.h             |  4 ---
 include/WallFollower.h     |  4 ++-
 main.cpp                   |  9 ++++++
 src/Config.cpp             |  2 +-
 src/ScenarioSimulation.cpp |  3 +-
 src/Simulation.cpp         | 23 +++++++-------
 src/WallFollower.cpp       | 76 ++++++++++++++++++++++------------------------
 9 files changed, 70 insertions(+), 62 deletions(-)
```

---

## Test Results

The functional test suite **passes** (`run-tests.sh` ends with `--- TESTS PASSED ---`).

Final summary lines from `test-output.txt`:

```
[ 35%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Renderer.cpp.o
[ 42%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/Simulation.cpp.o
[ 50%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/BatchSimulation.cpp.o
[ 57%] Building CXX object CMakeFiles/SimulationPathFinder.dir/src/ScenarioSimulation.cpp.o
[ 64%] Building CXX object CMakeFiles/SimulationPathFinder.dir/main.cpp.o
[ 71%] Linking CXX executable SimulationPathFinder
[100%] Built target SimulationPathFinder
--- BUILD SUCCEEDED ---
PASS: --scenario straight_tunnel produces clean tabular output
PASS: --scenario-suite produces tabular output with all expected columns
PASS: --debug enables WallFollower trace on stderr
PASS: --headless --batch 5 completes successfully
--- TESTS PASSED ---
```

### Build warnings

The spec constraint says **"Build must produce zero `-Wall` warnings."** The build is **not warning-free**. Warnings present in `test-output.txt`:

1. `include/Maze.h:36` — `-Wreorder` in `Maze::Maze` constructor (`cell_size_cm` initialized after `width_cells`).
2. `include/PerformanceMetrics.h:16` — `-Wreorder` in `PerformanceMetrics::PerformanceMetrics` (`stuck_step_count` initialized after `optimal_path_length_cm`).
3. `src/Pathfinder.cpp:41` — `-Wunused-but-set-variable` (`bool found = false;`).

These warnings are all **pre-existing on `origin/master`** (verified — `Pathfinder.cpp:41` already contains `bool found = false;` on master, and the affected headers are not touched by this PR). However the spec lists "zero `-Wall` warnings" as a hard constraint, and the PR took no action to satisfy it. The fixes are trivial (reorder two member-init lists, remove one unused variable).

---

## Requirements

### R1 — Unified physical configuration: ⚠️ Partial (regression)

- ✅ `config.json` updated: `cell_size_cm: 50`, `radius_cm: 10`, `minimum_distance_to_wall: 10` (config.json:5,10,11).
- ✅ `Config.h` adds `double minimum_distance_to_wall_cm` (include/Config.h:17).
- ✅ `Config.cpp` reads the new field (src/Config.cpp:28).
- ✅ `ScenarioSimulation::runScenario` now passes `config.cell_size_cm` to `Maze::createScenario` and uses it for start position math (src/ScenarioSimulation.cpp:11, 37–38, 82, 86–87). No hard-coded `20` literal remains.
- ❌ **`minimum_distance_to_wall_cm` is loaded but never read by any component.** The spec is explicit: *"All components that currently use this concept (WallFollower, collision detection, Simulation) must read it from the loaded `Config` object."* `grep` confirms only the load site references it; nothing consumes it.
- ❌ **Hard-coded physical constant introduced in `WallFollower`.** `include/WallFollower.h:56` declares `double robot_radius_cm_ = 15.0;` and `src/WallFollower.cpp:164,167` use `robot_radius_cm_ + 10.0` and `robot_radius_cm_ + 5.0` as "safe distance" thresholds. The previous code (now removed) at least referenced `config.robot_radius_cm` via an `extern Config config` (which was itself a latent bug — no such global is defined anywhere in the repo per `grep`). The fix replaces a broken reference with a **hard-coded literal that is now wrong**: the actual configured `robot_radius_cm` is **10**, not 15. This directly contradicts R1 ("config.json is the single source of truth"). The `+10.0` and `+5.0` offsets are exactly the kind of "minimum distance to wall" margins the new config field is meant to centralise.

This is the most serious issue in the PR. The diff acquired a debug-routing fix and simultaneously lost the (broken) link to the config, ending up with a regression in the consolidation goal.

### R2 — `--debug` CLI flag: ✅ Met

- `main.cpp:73,86–87,106–107,128–129`: flag parsed, default off, mapped onto `config.debug`.
- `Config.h:45`: `bool debug = false` field added.
- `Simulation.cpp:17`: `controller->setDebug(config.debug)` propagates the flag to `WallFollower`.
- `ScenarioSimulation.cpp:45`: same propagation in scenario mode.
- `Simulation.cpp:73–80, 176`: the eager "Robot initialized at …" / per-step logging now gated on `config.debug`.
- Test `PASS: --debug enables WallFollower trace on stderr` confirms the wiring end-to-end.

Minor: the preliminary-pass branch for `--debug` in `main.cpp:86–87` is a no-op with a stale comment ("handled in main parse loop"); it should simply be omitted from the preliminary pass. Cosmetic.

### R3 — WallFollower improvements: ✅ Met (with caveat)

1. ✅ `include/WallFollower.h:48` — `debug_ = false` default.
2. ✅ `include/WallFollower.h:43` — `void setDebug(bool d) { debug_ = d; }` added.
3. ✅ All ~25 debug prints in `src/WallFollower.cpp` switched from `std::cout` to `std::cerr` (verified by full diff).
4. ✅ Removed wasteful duplicate `double right_mean = right_side;` and every downstream `right_mean` use was rewritten as `right_side` directly. No behaviour change.
5. ✅ Removed the dead `extern Config config;` and `#include "Config.h"` from `WallFollower.cpp`.

Caveat: the substitution that replaced `config.robot_radius_cm` with a hard-coded `robot_radius_cm_ = 15.0` member produces "no observable behaviour change vs. the old (broken) extern symbol", but it is a step in the wrong direction — see R1.

### R4 — Complete or clean `Maze` interface: ✅ Met

- `include/Maze.h:46–48` — declarations of `hasWall` and `isWallBetween` are removed. No callers existed in the tree (`grep -r 'hasWall\|isWallBetween'` returns no hits). Build links cleanly; the spec explicitly allows removal as a valid option.

---

## Test Coverage

- The four shell-level tests in `run-tests.sh` cover the four functional verification steps from the spec (scenario, scenario-suite, --debug on stderr, batch). All pass.
- ⚠️ There is **no test asserting that `minimum_distance_to_wall_cm` is actually consumed**. Given the field is loaded but unused, the test suite cannot catch that regression. A test that toggles the value and observes a behavioural difference would have surfaced this; even a static assertion on usage would help.
- ⚠️ The `--debug` test only `grep`s for `"wall"` in stderr; it does not verify that **stdout is clean** when `--debug` is *not* passed. R3 promises debug-free stdout, so an absence-of-noise assertion on the no-flag path would be stronger. The "clean tabular output" scenario test does cover this indirectly.
- The robot-radius regression (10 in config vs 15 in code) is also invisible to the current tests, which only assert tabular output shape and exit codes, not collision counts or trajectory metrics.

---

## Code Quality

- **Hard-coded `15.0` in `WallFollower.h`** (line 56) — see R1. Central correctness concern.
- **Magic numbers `+ 10.0` and `+ 5.0` in `WallFollower.cpp:164,167`** — these are precisely the `minimum_distance_to_wall` values the new config field is meant to represent. They should be wired through.
- **Newline-at-EOF stripped from three files**:
  - `include/Config.h` (`\ No newline at end of file`)
  - `src/Simulation.cpp`
  - `src/ScenarioSimulation.cpp`
  - And `config.json` lost a trailing blank line (cosmetic).
  Inconsistent with the rest of the tree; a stray editor save, easy to fix.
- **Preliminary-pass `--debug` branch is dead code** in `main.cpp:86–87` — the comment says "handled in main parse loop", so the branch should be deleted rather than kept as an empty `else if`.
- **No `AGENTS.md` in `target-repo/`** (`glob` confirms absence). So no project-specific conventions to check against beyond the spec's own constraints — I have not fabricated any.
- **Pre-existing `-Wall` warnings left untouched** — see Test Results. The spec lists "zero -Wall warnings" as a constraint; even though the warnings predate this PR, the constraint is currently violated and the PR is the natural place to clean them up (three trivial fixes).

No security concerns; no algorithmic changes to maze generation or wall-following state machine; `BatchResults` and `saveSummary()` signatures are untouched (verified by diff stat — no `BatchSimulation.cpp` change).

---

## Verdict

**REQUEST CHANGES**

Blocking items (must fix before merge):

1. **R1 regression — remove the hard-coded `15.0` robot-radius constant in `WallFollower`.**
   `include/WallFollower.h:56` defines `double robot_radius_cm_ = 15.0;` while `config.json` sets `radius_cm: 10`. The wall-following safe-distance logic at `src/WallFollower.cpp:164,167` therefore uses a value that disagrees with config. Fix: either pass the relevant config values (`robot_radius_cm`, `minimum_distance_to_wall_cm`) into `WallFollower` via a `setConfig(const Config&)` / constructor / `setRobotRadius()` setter, or pass them as resolved thresholds into `computeVelocity` alongside the existing `front_clearance_threshold` / `side_wall_threshold` parameters.

2. **R1 — `minimum_distance_to_wall_cm` must actually be consumed.**
   Today the field is loaded by `src/Config.cpp:28` and read nowhere. The natural consumers are the `+ 10.0` / `+ 5.0` margins in `WallFollower.cpp:164,167` and the `config.robot_radius_cm + 2.0` near-miss check in `ScenarioSimulation.cpp:54`. The spec explicitly enumerates "WallFollower, collision detection, Simulation" as components that must read this value. If the team decides the field is not needed, remove it from `config.json` and `Config.h` rather than leaving dead config — but the spec wording strongly suggests it should be used.

Non-blocking but should be addressed before merge or in a follow-up:

3. Restore trailing newlines on `include/Config.h`, `src/Simulation.cpp`, `src/ScenarioSimulation.cpp`.
4. Delete the empty `--debug` preliminary-pass branch in `main.cpp:86–87`.
5. Resolve the three pre-existing `-Wall` warnings (`Maze.h` and `PerformanceMetrics.h` member-init reorder, `Pathfinder.cpp:41` unused `found`) so the spec's "zero `-Wall` warnings" constraint actually holds. If out-of-scope is the team's preference, the spec wording should be softened; but as written, the build does not satisfy the constraint.

R2, R3, R4 are otherwise in good shape and the four functional tests confirm the behavioural acceptance criteria from §Verification of the spec.
