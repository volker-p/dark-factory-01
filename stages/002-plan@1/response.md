Both files are complete and correct. Here's a summary of what was produced:

---

## Summary

### What I read and discovered

1. **Spec** (`specs/simulation-path-finder/wall-follower.md`): Target repo is `volker-p/SimulationPathFinder`. Feature spec requiring a complete rewrite of `WallFollower` with a new `Config`-based interface and absolute-angle stop-scan-drive algorithm.

2. **Target repo** has `CLAUDE.md` (not `AGENTS.md`) documenting a C++20/CMake project with SDL2 and nlohmann/json. Build command: `cmake --build cmake-build-debug`.

3. **Critical mismatch discovered**: The spec mandates a new interface `WallFollower(const Config&)` + `update(Robot&, const Maze&)`, but two callers — `Simulation.cpp` and `ScenarioSimulation.cpp` — use the old interface extensively (`computeVelocity()`, `updatePosition()`, `setDebug()`, `getState()`, etc.). Both callers must be updated.

4. **Config**: Three new fields need adding (`wall_follow_kp`, `wall_target_distance_cm`, `angle_tolerance_rad`); no JSON config keys need to change (use `value()` defaults).

---

### `plan.md` covers
- **Goal**, **files-to-change** table (6 files including 2 callers)
- **7-step checklist** with code-level detail (field additions, full algorithm sketch, `rotateToHeading` helper, sensor index strategy, caller update steps)
- **Test strategy** (3 scenario assertions, suite smoke, static grep checks)
- **12 identified risks** (sensor index approximation, field naming, detection threshold, DataLogger Action coupling, step-count budget, etc.)

### `run-tests.sh` covers
- Dependency detection/installation (`cmake`, `libsdl2-dev`)
- Submodule init + CMake configure + build (no pipes, `set -e` safe)
- `--- BUILD SUCCEEDED ---` and `--- TESTS PASSED ---` markers
- Static grep assertions (no banned symbols, all 3 config fields present)
- All 3 spec-mandated scenario assertions (`Traversal success: YES`)
- Suite table smoke test (header/column/row presence)
- Batch headless smoke test