I've written the review report to `/workspace/dark-factory-01/review-report.md`. The verdict is **REQUEST CHANGES**, consistent with the human gate decision of "[R] Rework".

## Summary of findings

**What works (R2, R3, R4):**
- `--debug` CLI flag correctly threaded through `Config` to `WallFollower` in both `Simulation` and `ScenarioSimulation`. Default off, on with `--debug`.
- `WallFollower`: `debug_=false` default, `setDebug()` setter, all ~25 prints moved `cout`→`cerr`, dead `right_mean` duplicate removed.
- `Maze::hasWall` / `Maze::isWallBetween` declarations removed (no callers existed) — clean build, allowed by spec.

**Blocking problems (R1):**
1. **Hard-coded `15.0` in `WallFollower.h:56`** when actual `radius_cm` is now `10`. The diff replaced `extern Config config; … config.robot_radius_cm` with a member literal — fixing a latent extern bug but introducing a value-disagreement regression.
2. **`minimum_distance_to_wall_cm` is loaded but never consumed.** The spec explicitly requires "WallFollower, collision detection, Simulation" to read it. The `+ 10.0` and `+ 5.0` magic offsets in `WallFollower.cpp:164,167` are exactly its intended consumers.

**Quality nits:** three files lost trailing newlines; an empty `--debug` no-op branch in the preliminary parse pass in `main.cpp`; three pre-existing `-Wall` warnings (Maze.h/PerformanceMetrics.h reorder, Pathfinder.cpp:41 unused `found`) that violate the spec's "zero `-Wall` warnings" constraint and the PR did not fix.

The functional test suite passes, but it cannot detect either of the blocking issues — it asserts output shape and exit codes, not config↔code consistency.