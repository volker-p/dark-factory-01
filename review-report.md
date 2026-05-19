# Review: simulation-path-finder/config-and-debug

## Test Results

**Test suite: PASSED** (per `bash run-tests.sh`).

Final summary lines from `test-output.txt`:

```
=== Batch complete: 5/5 successful ===

=== Final Results ===
Total time: 0.0731625 seconds
Successful runs: 5/5
Summary saved to ./data/batch_summary.txt

Training data generated successfully!
Check ./data/ for CSV files.
--- TESTS PASSED ---
```

Important caveats about what "passed" means here:

- The `run-tests.sh` script only checks **exit status** of each invocation and a single `grep -q -i "wall\|FOLLOW\|RECOVERY"` on the `--debug` stderr. It does **not** assert on scenario success, collision counts, or stdout cleanliness.
- The scenario suite output (printed via `--scenario-suite`) shows that **all five scenarios fail** with very high collision counts:

  ```
  SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS
  STRAIGHT_TUNNEL       NO       10000   1622.2    9.0      3999       3496
  CORNER_RIGHT          NO       10000   1607.6    9.0      4007       3555
  CORNER_LEFT           NO       10000   1588.9    9.0      4071       3603
  T_JUNCTION            NO       10000   1622.2    9.0      3999       3496
  FOUR_WAY_CROSSING     NO       10000   1582.9    9.0      4045       3628
  ```

  The spec's Verification step 3 (`./SimulationPathFinder --scenario-suite — low collision counts (robot fits corridors)`) is clearly not met in spirit. With `cell_size_cm=50` and `robot_radius_cm=10` the corridor is 50 cm wide and the 20 cm robot should fit — yet collisions are ~3500/run and `MIN_CLR=9.0` cm < `minimum_distance_to_wall=10`. Either the underlying controller / collision detection is independently broken, or the new config values are not actually being used end-to-end as intended.

- The batch run also shows the robot getting stuck on every run (`Robot stuck, terminating simulation.` for 5/5 runs, with ~1% exploration), even though it counts those as "successful" by the existing batch-completion definition.

- Build was performed with the project's default flags. `cmake --build build` produces **10 `-Wall` warnings** (`-Wreorder`, `-Wunused-but-set-variable`) — but all of them originate in files that are not touched by this PR (`SensorNoise.cpp`, `Pathfinder.cpp`, `PerformanceMetrics.{h,cpp}`). The PR does not introduce new warnings, but the spec's "zero `-Wall` warnings" constraint is technically still unsatisfied at the build level.

## Requirements

### R1 — Unified physical configuration: ⚠️ Partial

- `config.json` (lines 5, 10, 11): `cell_size_cm=50`, `radius_cm=10`, `minimum_distance_to_wall=10` ✅
- `include/Config.h:17`: `double minimum_distance_to_wall;` added ✅
- `src/Config.cpp:28`: loaded from JSON ✅
- `src/ScenarioSimulation.cpp:25` (in changed code): `Maze::createScenario(type, config.cell_size_cm)` — no hard-coded literal ✅
- `src/WallFollower.cpp:72`: `inner_radius = config.minimum_distance_to_wall;` reads via the existing `extern Config config;` global. This is consistent with the pre-existing pattern (`Renderer.cpp` does the same), but it does mean WallFollower silently depends on a global symbol defined in `main.cpp` rather than receiving it through its constructor / a passed `Config` ref. Acceptable but worth flagging.
- The other "physical-ish" constants in `WallFollower::computeVelocity` (`wall_following_velocity = 30.0`, `outer_radius = 35.0`, `turn_gain = 2.0`, `max_close_cycles = 80`, `max_lost_cycles = 120`) are **still hard-coded numeric literals**. The spec phrasing — "All components that currently use this concept (WallFollower, collision detection, Simulation) must read it from the loaded `Config` object" — refers to `minimum_distance_to_wall` specifically (which is wired through), so this is arguably out of scope, but `wall_following_velocity=30.0` duplicating `config.linear_velocity_cm_per_s=30` is the same class of bug R1 was meant to eliminate.

### R2 — `--debug` CLI flag: ✅ Met

- `main.cpp:73,87-88,105-106,144` — flag parsed, default off, recognised in both the preliminary and main parse passes.
- Threaded through to `ScenarioSimulation(config, debug_mode)` (`main.cpp:147`) and `BatchSimulation(config, debug_mode)` (`main.cpp:192`).
- `ScenarioSimulation` and `BatchSimulation` forward the flag to `Simulation`/`WallFollower` via `setDebug` (`src/ScenarioSimulation.cpp:25`, `src/Simulation.cpp:17`, `src/BatchSimulation.cpp:39`).

### R3 — WallFollower improvements: ✅ Met

1. Default `debug_=false`: `include/WallFollower.h:49` ✅
2. `void setDebug(bool d) { debug_ = d; }`: `include/WallFollower.h:28` ✅
3. All debug output routed to `std::cerr` in `src/WallFollower.cpp` (e.g. lines 36, 49, 101, 115, and matching cases throughout the file). The previous large commented-out Python pseudocode block was removed — that's a fine cleanup ✅
4. Obvious wasteful patterns: the implementation removed a large dead commented-out block (−110 lines net). No obvious copy/redundant-check fixes claimed; spec said "without changing observable behaviour", so this is acceptable.

### R4 — Complete or clean `Maze` interface: ✅ Met

- `include/Maze.h` declarations for `hasWall` and `isWallBetween` were **removed** (diff drops lines 49–51 of original). No call sites exist anywhere in the tree (`grep hasWall|isWallBetween` in `target-repo` returns nothing). This matches the "remove if no caller" branch of R4. Build links cleanly.

### Constraints

- **Zero `-Wall` warnings**: ❌ violated (10 pre-existing warnings), but not introduced by this PR.
- **`BatchResults` / `saveSummary()` unchanged**: ✅ — `include/BatchSimulation.h` only adds a `debug_` member and a defaulted constructor parameter; struct and method signature unchanged.
- **Core maze generation not modified**: ✅ (no diff in `Maze.cpp`/maze-generation code).
- **`--headless --batch N` and `--scenario*` keep working**: ✅ functionally (they run to completion), though scenario *success rates* are bad — see "Test Results".

## Test Coverage

- The `run-tests.sh` harness runs each of the spec's five verification commands once. It correctly:
  - Drops stderr to `/dev/null` in step 1, 2, 4 (so a debug-flooded stdout would be visible — and there is none).
  - Captures stderr to `/tmp/dbg.txt` and greps for `wall|FOLLOW|RECOVERY` when `--debug` is set.

- **Gaps**:
  - No assertion that the *non-debug* run produces a quiet stdout. A regression that prints debug to stdout would still "pass" because the script only checks the exit code.
  - No assertion on scenario success or collision counts. The fact that all five scenarios fail with thousands of collisions is invisible to the test gate.
  - The grep pattern is `-i "wall\|FOLLOW\|RECOVERY"`, broader than the spec's `grep -q "wall"`. Not wrong, but weaker as a verification.
  - No unit tests for `Config::loadFromFile` parsing the new `minimum_distance_to_wall` field; if it were missing from JSON, the loader would throw at runtime.

## Code Quality

- No `AGENTS.md` exists in `target-repo`, so no project-specific conventions to check beyond pre-existing style.
- **Missing-newline-at-EOF**: 4 files now end without a trailing newline (`include/ScenarioSimulation.h`, `include/Simulation.h`, `src/ScenarioSimulation.cpp`, `src/Simulation.cpp`). Minor, but it's a regression introduced by this PR and shows up as `\ No newline at end of file` markers in the diff.
- The cleanup of the large commented-out Python pseudocode block in `WallFollower.cpp` is a nice tidy-up.
- The `extern Config config;` global continues to be used by `WallFollower.cpp` to read `minimum_distance_to_wall`. Consistent with the existing `Renderer.cpp` pattern but it remains a fragile coupling — the `WallFollower` ctor takes no `Config` even though the class now depends on one. Not blocking, but worth noting.
- `wall_following_velocity = 30.0` and `outer_radius = 35.0` in `WallFollower::computeVelocity` remain hard-coded. The spec only mandated `minimum_distance_to_wall` be unified, but R1's spirit ("config.json is the single source of truth for all physical parameters") arguably covers these too. Strictly out of scope per the explicit list, but a reviewer should flag it.
- The big surprise visible from `test-output.txt` is that the chosen config values *do not* actually let the robot navigate the scenarios. With a 50 cm corridor and a 20 cm-diameter robot, ~3500 collisions/run and `MIN_CLR=9.0 < minimum_distance_to_wall=10` strongly suggest something else (maze geometry, sensor model, or controller) is still broken. The spec presented these values as "the robot fits corridors" — that is empirically false here. Whether fixing this is in scope for this spec is a judgement call; the spec is explicitly framed as the *config consolidation* fix that should enable navigation, so the fact that it doesn't is significant signal.

## Verdict

**REQUEST CHANGES** — with one main blocking concern and a few smaller items:

1. **Blocking — verification step 3 fails in substance.** The whole motivation for R1 (per the spec's Background) was that the 15 cm robot in 20 cm corridors couldn't fit. The new values are supposed to make the robot fit a 50 cm corridor, but the scenario suite shows *all five scenarios failing with ~3500 collisions and `MIN_CLR=9.0`*. Either (a) the new config values are not actually reaching the collision/sensor code paths, (b) the chosen values are still wrong, or (c) something else in `ScenarioSimulation`/`Robot`/`Maze` needs adjusting for the values to matter. Please investigate why the unified config does not produce navigable scenarios, and either fix it or update the spec/values to reflect reality. The test script must also be tightened to assert at least *some* scenario succeeds, otherwise this regression will recur silently.

2. **Non-blocking but should fix before merge:**
   - Tighten `run-tests.sh` step 1/2 to assert quiet stdout (e.g. `[ ! -s output ]` after redirecting stdout to a file), so a future regression that re-floods stdout is caught.
   - Restore trailing newlines on the four files that lost them (`include/ScenarioSimulation.h`, `include/Simulation.h`, `src/ScenarioSimulation.cpp`, `src/Simulation.cpp`).
   - Consider also routing `wall_following_velocity` and `outer_radius` through `Config` since they duplicate values that already live there — fully aligned with R1's intent.

If item (1) is judged out of scope for this particular spec (i.e. the PR truly only consolidates *how* config is read, not *whether* the resulting values navigate), then this can be reduced to APPROVE with the non-blocking notes — but the spec's own Verification section explicitly demands "low collision counts (robot fits corridors)" as an acceptance check, and that check fails today.
