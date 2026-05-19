# Review: simulation-path-finder/config-and-debug (post-Rework)

**Important context:** the prior `gate_pr` decision was **Rework**. The subsequent
`implement` step **failed**, then `test` re-ran the existing harness and passed.
The HEAD of `target-repo` is still the single commit `34a2d62 Consolidate physical
config, add --debug flag, fix WallFollower debug output` — i.e. **no new code has
landed since the previous review**. None of the items flagged at the previous
review have been addressed. This report reflects that state.

## Test Results

**Test suite: PASSED** (`bash run-tests.sh` exited 0).

Final lines of `test-output.txt`:

```
=== Running simulation 5/5 ===
Robot stuck, terminating simulation.
Logged 2615 samples to ./data/training_data_2026-05-19_08-43-32_run5.csv
Simulation complete: 1% explored, 2615 steps, 423.376 cm traveled

=== Batch complete: 5/5 successful ===

=== Final Results ===
Total time: 0.0666112 seconds
Successful runs: 5/5
Summary saved to ./data/batch_summary.txt

Training data generated successfully!
Check ./data/ for CSV files.
--- TESTS PASSED ---
```

What "passed" means here:

- `run-tests.sh` only checks **exit codes** of each verification command, plus a
  single `grep -q -i "wall\|FOLLOW\|RECOVERY"` on the `--debug` stderr. It does
  not assert on scenario success, collision counts, or stdout cleanliness.
- The scenario-suite output in the same test log shows **all five scenarios
  failing with very high collision counts** and a min-clearance below the new
  `minimum_distance_to_wall`:

  ```
  SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS
  STRAIGHT_TUNNEL       NO       10000   1622.2    9.0      3999       3496
  CORNER_RIGHT          NO       10000   1607.6    9.0      4007       3555
  CORNER_LEFT           NO       10000   1588.9    9.0      4071       3603
  T_JUNCTION            NO       10000   1622.2    9.0      3999       3496
  FOUR_WAY_CROSSING     NO       10000   1582.9    9.0      4045       3628
  ```

  The spec's Verification step 3 (`./SimulationPathFinder --scenario-suite` →
  "low collision counts (robot fits corridors)") is not met in substance.
  With `cell_size_cm=50` and `robot_radius_cm=10` the corridor is 50 cm wide
  for a 20 cm robot and should be trivially navigable, yet `MIN_CLR=9.0 <
  minimum_distance_to_wall=10` on every scenario.

- The batch run also reports `Robot stuck, terminating simulation.` on every
  one of the 5 runs (~1 % explored), even though the harness still reports
  5/5 "successful" because the existing batch logic counts a clean termination
  as success.

- Build runs with default flags; `cmake --build build` still emits the
  pre-existing `-Wreorder` / `-Wunused-but-set-variable` warnings from files
  not touched by this PR (`SensorNoise.cpp`, `Pathfinder.cpp`,
  `PerformanceMetrics.{h,cpp}`). The PR introduces no new warnings.

## Requirements

### R1 — Unified physical configuration: ⚠️ Partial

- `config.json` lines 5, 10, 11: `cell_size_cm=50`, `radius_cm=10`,
  `minimum_distance_to_wall=10` ✅
- `include/Config.h:17`: `double minimum_distance_to_wall;` ✅
- `src/Config.cpp:28`: `j["robot"]["minimum_distance_to_wall"]` loaded ✅
- `src/ScenarioSimulation.cpp:11,37,38,82,86,87`: `Maze::createScenario(type,
  config.cell_size_cm)` and start/goal math read `config.cell_size_cm` — no
  hard-coded literal ✅
- `src/WallFollower.cpp:72`: `inner_radius = config.minimum_distance_to_wall;`
  reads via `extern Config config;` (pre-existing pattern in `Renderer.cpp`).
  Functionally correct, but couples `WallFollower` to a global rather than
  passing `Config` through the constructor.
- `src/WallFollower.cpp:70,71,73,75,76`: `wall_following_velocity = 30.0`,
  `outer_radius = 35.0`, `turn_gain = 2.0`, `max_close_cycles = 80`,
  `max_lost_cycles = 120` are **still hard-coded numeric literals** in
  `computeVelocity`. `wall_following_velocity=30.0` duplicates
  `config.linear_velocity_cm_per_s=30` exactly — the same class of
  scatter that R1 was meant to eliminate. The spec's explicit field list only
  names `minimum_distance_to_wall`, so this is arguably out of scope, but it
  is contrary to the stated R1 intent ("config.json is the single source of
  truth for *all* physical parameters").

### R2 — `--debug` CLI flag: ✅ Met

- `main.cpp:73,87–88,106–107,147,192`: flag parsed (default off), recognised
  in both the preliminary and main parse passes, included in `--help`
  output (`main.cpp:60`).
- Wired to `ScenarioSimulation(config, debug_mode)` (`main.cpp:147`) and
  `BatchSimulation(config, debug_mode)` (`main.cpp:192`).
- Forwarded to `Simulation`/`WallFollower` via `setDebug`
  (`src/ScenarioSimulation.cpp:45`, `src/Simulation.cpp:17`,
  `src/BatchSimulation.cpp:39`).
- `src/Simulation.cpp:73–81` and the big per-step diagnostic block at
  `src/Simulation.cpp:161–262` are now gated on `if (debug_)`.

### R3 — WallFollower improvements: ✅ Met

1. `include/WallFollower.h:49`: `bool debug_ = false;` ✅
2. `include/WallFollower.h:28`: `void setDebug(bool d) { debug_ = d; }` ✅
3. All debug output in `src/WallFollower.cpp` is routed to `std::cerr`
   (e.g. lines 36, 49, 101, 115, 363, 373, 382). The previous ~110-line
   block of commented-out Python pseudocode was also removed — fine cleanup.
4. No obvious copy/redundant-check fixes beyond the dead-code removal;
   spec says "without changing observable behaviour" so this is acceptable.

### R4 — Complete or clean `Maze` interface: ✅ Met

- `include/Maze.h` declarations for `hasWall` and `isWallBetween` removed
  (diff drops lines 49–51 of the original). `grep -r hasWall\|isWallBetween
  target-repo` returns no matches, confirming there were no callers. Build
  links cleanly. This is the "remove if no caller" branch of R4.

### Constraints

- **Zero `-Wall` warnings**: ❌ violated at the build level (pre-existing
  warnings in untouched files), but no new warnings introduced by this PR.
- **`BatchResults` / `saveSummary()` unchanged**: ✅ (`include/BatchSimulation.h`
  only adds `bool debug_` and a defaulted ctor param).
- **Core maze generation untouched**: ✅ (no diff in `Maze.cpp`).
- **`--headless --batch N` and `--scenario*` keep working**: ✅ functionally;
  scenario *success rates* are still bad — see Test Results.

## Test Coverage

- `run-tests.sh` runs each of the spec's five verification commands once:
  - stderr is dropped to `/dev/null` in steps 1, 2, 4, so a regression that
    flooded *stdout* during a non-debug run would be visible. None observed.
  - stderr is captured to `/tmp/dbg.txt` in step 3 and grep'd for
    `wall|FOLLOW|RECOVERY` (broader than the spec's `grep -q "wall"`,
    but not wrong).

- **Gaps** (unchanged from the previous review):
  - No assertion that a non-debug run produces *quiet stdout*. A future
    regression printing debug to stdout would still pass.
  - No assertion on scenario success or collision counts. The fact that all
    five scenarios fail with thousands of collisions is invisible to the
    test gate — exactly the situation we see now.
  - No assertion that `config.json` actually loads (e.g. parsing the new
    `minimum_distance_to_wall` field); a missing field would only fail at
    runtime via an nlohmann::json exception.

## Code Quality

- No `AGENTS.md` exists in `target-repo`; only pre-existing style applies.
- **Trailing-newline regressions**: `include/ScenarioSimulation.h`,
  `include/Simulation.h`, `src/ScenarioSimulation.cpp`, and
  `src/Simulation.cpp` all now end without a final newline (`\ No newline at
  end of file` markers in the diff). Minor but easy to fix.
- `extern Config config;` global continues to be used by
  `src/WallFollower.cpp:8` to read `minimum_distance_to_wall`. Consistent
  with `Renderer.cpp` but a fragile coupling — `WallFollower`'s ctor takes
  no `Config` even though the class now depends on one. Not a regression;
  the PR did not introduce the global.
- Removing the long block of commented-out Python pseudocode in
  `WallFollower.cpp` is a good cleanup.
- The empirical failure of the scenario suite under the new "navigable"
  config values is the most surprising thing for a reviewer to see. With
  a 50 cm corridor, a 20 cm-diameter robot, and `MIN_CLR=9.0 < 10`, either
  (a) collision/sensor geometry is not actually reading the new
  `cell_size_cm` end-to-end, (b) the chosen values are still wrong, or
  (c) something else in `Robot`/`Maze`/`WallFollower` is independently
  broken. The spec's Background section frames this PR as the fix for
  exactly this navigation problem.

## Verdict

**REQUEST CHANGES** — same blocking item as the previous review, since the
post-Rework `implement` step failed and no code changed:

1. **Blocking — Verification step 3 fails in substance.** The spec's
   stated motivation (Background §1) is that a 15 cm robot couldn't fit a
   20 cm corridor. The new config (50 cm cells, 10 cm radius) is supposed
   to fix that, but the scenario suite shows all five scenarios failing
   with ~3500 collisions/run and `MIN_CLR=9.0 < minimum_distance_to_wall=
   10`. Investigate why the unified config does not yield navigable
   scenarios — either the values aren't reaching the collision/sensor
   path end-to-end, or the chosen values are still wrong, or another
   bug in `ScenarioSimulation`/`Robot`/`Maze` needs fixing. Update
   `run-tests.sh` to assert at least one scenario succeeds (or that
   collisions are below a sane threshold), so this regression cannot
   recur silently.

2. **Should fix before merge:**
   - Restore trailing newlines on `include/ScenarioSimulation.h`,
     `include/Simulation.h`, `src/ScenarioSimulation.cpp`,
     `src/Simulation.cpp`.
   - Tighten `run-tests.sh` steps 1/2 to assert quiet stdout (e.g.
     redirect stdout to a file and check it is silent / does not contain
     the WallFollower trace markers), catching any future regression
     that re-floods stdout.
   - Consider routing `wall_following_velocity` and `outer_radius` (and
     the other literals in `WallFollower::computeVelocity`) through
     `Config` — fully aligned with R1's intent and removes the
     `linear_velocity_cm_per_s` duplication.
   - **Process note:** the post-Rework `implement` stage failed. The
     workflow then ran `test` against the unchanged tree and passed.
     The implementer needs to actually land changes addressing items
     (1) and (2) above before another `gate_pr`.
