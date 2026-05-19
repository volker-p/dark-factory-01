# Implementation Plan: Physical Configuration Consolidation & Debug Control

## Goal

Eliminate hard-coded physical constants, make `config.json` the single source of truth for all physical parameters, add a `--debug` CLI flag to control debug output, apply straightforward improvements to `WallFollower`, and resolve the incomplete `Maze` interface.

---

## Files to Change

| File | What Changes and Why |
|---|---|
| `config.json` | Update `robot.radius_cm` to 10; add `minimum_distance_to_wall: 10`; `cell_size_cm` is already 50 (confirm). These are the authoritative physical values. |
| `include/Config.h` | Add `double minimum_distance_to_wall` field so all components can read it from the loaded config object. |
| `src/Config.cpp` | Load `minimum_distance_to_wall` from the new JSON field and store it in the struct. |
| `include/WallFollower.h` | Change `debug_` default to `false`; add public `void setDebug(bool d)` method; remove stale Python comments (large commented-out block). |
| `src/WallFollower.cpp` | Route all `std::cout` debug/trace output to `std::cerr`; replace hard-coded `inner_radius` (18.0) with `config.minimum_distance_to_wall`; fix unnecessary copies/redundant checks (see checklist). |
| `src/Simulation.cpp` | After constructing `WallFollower`, call `controller->setDebug(debug_flag)` if debug mode is active; move the always-on verbose step-logging block behind the debug flag (currently it floods stdout unconditionally at every 5 steps). |
| `include/Simulation.h` | Store `bool debug_` member; update constructor to accept `bool debug = false`. |
| `src/ScenarioSimulation.cpp` | No code change needed — `runScenario` already reads `config.cell_size_cm` (the hard-coded literal `20` is gone, already uses `config.cell_size_cm`). Pass `config.minimum_distance_to_wall` as `inner_radius` to `WallFollower` if needed — but WallFollower reads from the global `config` object directly. Verify no other literals remain. |
| `main.cpp` | Parse `--debug` flag; set a `bool debug_mode` variable; pass it to `Simulation` and `ScenarioSimulation` objects; add `--debug` to `printUsage()`. |
| `include/ScenarioSimulation.h` | No struct/signature changes (constraint: `BatchResults` / `saveSummary` untouched). Optionally add `bool debug_` member if needed to propagate flag. |
| `src/Maze.cpp` | No changes needed for `hasWall`/`isWallBetween` (declarations are in header only). |
| `include/Maze.h` | Remove the two dead declarations `hasWall` and `isWallBetween` — they have no implementation and no callers; leaving them causes a link error if anyone eventually links them. |

---

## Implementation Checklist

### Step 1 — Update `config.json`
1. Confirm `"cell_size_cm": 50` is already set (it is — no change needed).
2. Change `"radius_cm"` under `"robot"` from `15` to `10`.
3. Add `"minimum_distance_to_wall": 10` to the `"robot"` object (or create a new top-level `"physics"` object — but the `"robot"` section is the natural home).

### Step 2 — Add `minimum_distance_to_wall` to `Config.h` and `Config.cpp`
1. In `include/Config.h`, add `double minimum_distance_to_wall;` after `robot_radius_cm`.
2. In `src/Config.cpp`, inside `Config::loadFromFile`, add:
   ```cpp
   config.minimum_distance_to_wall = j["robot"]["minimum_distance_to_wall"];
   ```
   immediately after the `robot_radius_cm` line.

### Step 3 — Remove dead `Maze` interface methods
1. In `include/Maze.h`, delete the two lines:
   ```cpp
   bool hasWall(double x_cm, double y_cm, int direction) const;
   bool isWallBetween(double x1_cm, double y1_cm, double x2_cm, double y2_cm) const;
   ```
2. No changes to `src/Maze.cpp` are required (no implementations existed).

### Step 4 — Fix `WallFollower.h`
1. Change the default initializer of `debug_` from `true` to `false`:
   ```cpp
   bool debug_ = false;
   ```
2. Add a public `setDebug` method in the public section of the class:
   ```cpp
   void setDebug(bool d) { debug_ = d; }
   ```
3. Remove the large block of commented-out Python code (lines ~390–488 in `WallFollower.cpp`) — dead weight; place in `.cpp` not header. This is in `.cpp`, not `.h`; see Step 5.

### Step 5 — Fix `WallFollower.cpp`
1. Change every `std::cout` used for debug/trace output to `std::cerr`. Specifically, all the state-transition messages (`"FOUND wall → FOLLOW_WALL"`, `"Obstacle ahead! → AVOID_COLLISION"`, `"Timeout detected → RECOVERY"`, etc.) and the stuck/close warnings.
2. Replace the hard-coded `inner_radius = 18.0` with `config.minimum_distance_to_wall`:
   ```cpp
   double inner_radius = config.minimum_distance_to_wall;
   ```
   This also fixes the safe-left-distance formula which already reads `config.robot_radius_cm`.
3. Remove the large commented-out Python code block (lines ~390–488) — it is dead code and clutters the file.
4. In `updatePosition`, the two `std::cout` debug lines should also become `std::cerr`.
5. **Wasteful pattern**: `double right_mean = right_side;` on line 88 is a needless alias — but since it is used throughout the function as `right_mean`, simply leave it or inline it. The more impactful fix is the `inner_radius` from config.

### Step 6 — Update `Simulation.cpp` and `Simulation.h` to support `--debug`
1. In `include/Simulation.h`, add a `bool debug_` private member and change the constructor signature to:
   ```cpp
   Simulation(const Config& cfg, bool debug = false);
   ```
2. In `src/Simulation.cpp`, update the constructor to accept and store `debug`:
   ```cpp
   Simulation::Simulation(const Config& cfg, bool debug)
       : config(cfg), debug_(debug), ... {
       controller = std::make_unique<WallFollower>();
       controller->setDebug(debug_);
       ...
   }
   ```
3. In `Simulation::run()`, gate the verbose step-by-step logging block (the large `if (should_log)` block and the `initializeRobot` `std::cout` lines) behind `if (debug_)`. The non-debug completion messages (`"Maze completion threshold reached!"`, `"Robot stuck"`, `"Simulation complete"`) can remain on stdout.
4. Also gate `initializeRobot()`'s two `std::cout` lines behind the debug flag (either add `debug_` member accessible there, or move the output behind a parameter).

### Step 7 — Update `ScenarioSimulation` to support `--debug`
1. In `include/ScenarioSimulation.h`, add `bool debug_` private member; update constructor:
   ```cpp
   explicit ScenarioSimulation(const Config& cfg, bool debug = false);
   ```
2. In `src/ScenarioSimulation.cpp`, update the constructor to store `debug_` and call `setDebug` on the `WallFollower` after construction:
   ```cpp
   WallFollower controller;
   controller.setDebug(debug_);
   ```

### Step 8 — Add `--debug` to `main.cpp`
1. Add `bool debug_mode = false;` alongside the other flags at the top of `main`.
2. In the preliminary pass loop (and in the main parse loop), detect `--debug`:
   ```cpp
   } else if (strcmp(argv[i], "--debug") == 0) {
       debug_mode = true;
   }
   ```
3. Update `printUsage()` to include:
   ```
   --debug               Enable debug/trace output from all components
   ```
4. When constructing `ScenarioSimulation`, pass `debug_mode`:
   ```cpp
   ScenarioSimulation sim(config, debug_mode);
   ```
5. When constructing `BatchSimulation`, thread `debug_mode` through. Read `BatchSimulation.h` to see if it constructs `Simulation` internally — if so, the `debug_mode` needs to be stored in `BatchSimulation` and passed to each `Simulation` it creates.

### Step 9 — Verify no other hard-coded physical literals remain
1. Search `main.cpp`, `Simulation.cpp`, `BatchSimulation.cpp`, `ScenarioSimulation.cpp` for any numeric literals that represent physical dimensions (`20`, `15`, `25`, etc.) that should come from config. Key known issue was `ScenarioSimulation` — already reads `config.cell_size_cm` (confirmed in current code). The `front_threshold = config.robot_radius_cm + 20.0` in `Simulation.cpp` is a composite formula, not a raw physical constant; this is acceptable.

### Step 10 — Zero-warning build check
1. After all changes, build with `-Wall` (already set in `CMakeLists.txt`).
2. Fix any warnings introduced: unused variable from removed code, sign-compare issues, etc.

---

## Test Strategy

### Tests to run
The repository has no dedicated unit-test framework. Verification is done by running the binary. Use the commands from the spec's **Verification** section as the test suite:

1. **Clean build** — confirms no warnings:
   ```bash
   cmake -B build && cmake --build build 2>&1 | grep -E "warning:|error:"
   ```
2. **Scenario run (no debug)** — confirms no debug flood on stdout:
   ```bash
   ./build/SimulationPathFinder --scenario straight_tunnel 2>/dev/null
   # output must be clean tabular metrics, no state-transition messages
   ```
3. **Full scenario suite** — confirms low collision counts with 10cm robot in 50cm corridors:
   ```bash
   ./build/SimulationPathFinder --scenario-suite 2>/dev/null
   ```
4. **Debug flag** — confirms WallFollower trace appears on stderr when `--debug` is passed:
   ```bash
   ./build/SimulationPathFinder --debug --scenario straight_tunnel 2>/tmp/dbg.txt
   grep -q "wall\|FOLLOW\|RECOVERY" /tmp/dbg.txt
   ```
5. **Batch mode** — confirms existing batch functionality is unbroken:
   ```bash
   ./build/SimulationPathFinder --headless --batch 5
   ```

### Existing tests that may be affected
- `run_test.sh` and `test.sh` in the repo root — read these before running to ensure they still pass.
- The `test_output/` directory may contain golden outputs; re-run and compare if needed.

### Regression risks
- Config loading: adding `minimum_distance_to_wall` will throw `nlohmann::json` exception if the field is missing from JSON. Always add the field to `config.json` before changing `Config.cpp`.
- `ScenarioSimulation` already reads `config.cell_size_cm` — confirmed no regression there.
- `BatchSimulation` constructs `Simulation` objects — ensure the `debug` flag threads through correctly.

---

## Risks and Edge Cases

| Risk | Mitigation |
|---|---|
| `nlohmann::json` throws if `minimum_distance_to_wall` key is absent | Add key to `config.json` **before** adding the load line in `Config.cpp`. |
| Changing `robot_radius_cm` from 15 to 10 affects `WallFollower.cpp` safe-left-distance formula (`config.robot_radius_cm + 10.0`) — threshold drops from 25cm to 20cm | This is intentional (smaller robot needs less clearance). Verify via scenario suite that collision counts do not increase. |
| Moving verbose step-logging in `Simulation.cpp` behind `debug_` flag may hide information during debugging | That is the spec intent; trace goes to stderr via WallFollower, which is still available with `--debug`. |
| `BatchSimulation` may not have a path to propagate `debug_mode` | Read `include/BatchSimulation.h` and `src/BatchSimulation.cpp` before Step 8; add `bool debug_` member and constructor parameter if needed. |
| Removing commented-out Python block from `WallFollower.cpp` is safe but must be done carefully | The block is entirely within `/* ... */` comment delimiters — verify the delimiters before deletion to avoid accidentally removing live code. |
| `Simulation.h` constructor signature change may break `BatchSimulation.cpp` if it calls `Simulation(cfg)` directly | Update `BatchSimulation.cpp` call site to `Simulation(cfg, debug_)`. |
| `-Wall` may surface sign-compare warnings from `sensor_readings.size()` comparisons in `Simulation.cpp` | These pre-exist; fix by casting to `int` or using `static_cast<size_t>`. Only fix if newly introduced. |
