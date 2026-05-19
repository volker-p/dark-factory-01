# Implementation Plan — Physical Configuration Consolidation & Debug Control

## Goal

Eliminate hard-coded physical constants by making `config.json` the single source of truth, add a `--debug` CLI flag that globally controls debug output (defaulting to off), apply focused improvements to `WallFollower`, and resolve the incomplete `Maze` interface by removing the two unimplemented declarations.

---

## Files to Change

| File | What changes and why |
|---|---|
| `config.json` | Update `robot.radius_cm` to 10, add `"minimum_distance_to_wall": 10` under `robot`, keep `cell_size_cm` at 50 (already correct) |
| `include/Config.h` | Add `double minimum_distance_to_wall` field to the Config struct |
| `src/Config.cpp` | Load `minimum_distance_to_wall` from the `robot` JSON object |
| `include/WallFollower.h` | Change `debug_` default from `true` to `false`; add public `void setDebug(bool d)` method |
| `src/WallFollower.cpp` | Replace all `std::cout` debug prints with `std::cerr`; replace hard-coded `config.robot_radius_cm + 10.0` and `config.robot_radius_cm + 5.0` safe-distance literals with `config.minimum_distance_to_wall`-based expressions; fix minor wasteful patterns (unnecessary `right_mean` alias) |
| `src/Simulation.cpp` | After constructing `WallFollower`, call `controller->setDebug(debug_flag)` where `debug_flag` is passed in from `Config`; move the verbose `std::cout` step-logging block to be gated on a `debug` member or the same flag; silence the two `initializeRobot()` `std::cout` lines when debug is off |
| `include/Simulation.h` | No signature changes required; debug flag flows through `Config` |
| `main.cpp` | Parse `--debug` flag; store it in a `bool debug` local; after loading config pass it via `config.debug = debug` (or set it before calling `ScenarioSimulation`/`BatchSimulation`); add `--debug` to `printUsage()` |
| `include/Config.h` | Add `bool debug` field (defaulting to `false`) so the flag can be threaded through to all components that receive a `Config` reference |
| `src/Config.cpp` | Default `config.debug = false` (not loaded from JSON; set programmatically from CLI) |
| `src/ScenarioSimulation.cpp` | Pass `config.debug` to `WallFollower` via `controller.setDebug(config.debug)` |
| `src/Maze.cpp` | No change needed (no `hasWall`/`isWallBetween` implementation required) |
| `include/Maze.h` | Remove the two unused declarations `hasWall` and `isWallBetween` (no callers exist; removing cleans up the interface and eliminates latent link errors) |

---

## Implementation Checklist

### Step 1 — Update `config.json`
1. Change `"radius_cm"` under `robot` from `15` to `10`.
2. Add a new key `"minimum_distance_to_wall": 10` under the `robot` object.
3. Confirm `maze.cell_size_cm` is already `50` (it is; no change needed).

### Step 2 — Add `minimum_distance_to_wall` and `debug` to `Config.h`
1. In the **Robot configuration** section of `Config.h`, add:
   ```cpp
   double minimum_distance_to_wall;
   ```
2. In the **Simulation/top-level section** (or add a new section), add:
   ```cpp
   bool debug;
   ```
   This field is set by `main.cpp` from the `--debug` CLI flag, not loaded from JSON.

### Step 3 — Load `minimum_distance_to_wall` in `Config.cpp`
1. After the line that loads `robot_radius_cm`, add:
   ```cpp
   config.minimum_distance_to_wall = j["robot"]["minimum_distance_to_wall"];
   ```
2. After the existing defaults block (just before the `validate()` call), initialise:
   ```cpp
   config.debug = false;
   ```
   (The field is set by `main.cpp` after loading; initialising it here prevents any uninitialized-read in tests that construct `Config` directly.)

### Step 4 — Fix `WallFollower.h`
1. Change the in-class initialiser from `bool debug_ = true;` to `bool debug_ = false;`.
2. Add a new public method after `forceRecovery()`:
   ```cpp
   void setDebug(bool d) { debug_ = d; }
   ```

### Step 5 — Fix `WallFollower.cpp`
1. Replace every occurrence of `std::cout` in debug-guarded branches with `std::cerr`. This covers:
   - The timeout detection block (`"Timeout detected → RECOVERY"`)
   - All state-transition prints in `FIND_WALL`, `FOLLOW_WALL`, `AVOID_COLLISION`, `TURN_CORNER`, `RECOVERY`
   - The `updatePosition()` stuck-detection prints
2. Replace the two hard-coded safe-distance calculations that reference `config.robot_radius_cm + 10.0` and `config.robot_radius_cm + 5.0` with expressions using `config.minimum_distance_to_wall`:
   ```cpp
   // Before:
   double safe_left_distance = config.robot_radius_cm + 10.0;
   if (left_side < config.robot_radius_cm + 5.0) { ...
   // After:
   double safe_left_distance = config.robot_radius_cm + config.minimum_distance_to_wall;
   if (left_side < config.robot_radius_cm + config.minimum_distance_to_wall * 0.5) { ...
   ```
   *(This maintains the same proportional relationship while reading from config.)*
3. Remove the redundant local variable `right_mean` that is set to `right_side` and never diverges:
   ```cpp
   // Before:
   double right_side = sensors[2];
   double right_mean = right_side;   // pointless alias
   // After:
   double right_mean = sensors[2];
   ```
   Also remove the now-unused `double left_side = sensors[3];` and replace its sole use (`left_side`) by inlining `sensors[3]`. *(Keep `left_side` as a named local if it improves readability — the key fix is removing `right_mean` alias.)*

### Step 6 — Fix `Simulation.cpp`
1. After `controller = std::make_unique<WallFollower>();` in the constructor, add:
   ```cpp
   controller->setDebug(config.debug);
   ```
2. Gate the verbose step-logging block (lines ~173–258) behind `if (config.debug)` instead of the existing `if (should_log)` condition that always fires. Replace the outer check:
   ```cpp
   if (should_log) { ... }
   ```
   with:
   ```cpp
   if (config.debug && should_log) { ... }
   ```
3. Gate the two `initializeRobot()` `std::cout` lines (robot position + cell walls) behind `if (config.debug)`.
4. Leave the non-debug `std::cout` lines (maze completion threshold, robot stuck, simulation complete) unchanged — they are user-facing status messages, not debug noise.

### Step 7 — Fix `main.cpp`
1. Add `bool debug = false;` near the top of `main()` alongside the other local flags.
2. In the argument-parsing loop, add:
   ```cpp
   } else if (strcmp(argv[i], "--debug") == 0) {
       debug = true;
   }
   ```
3. After `config = Config::loadFromFile(config_file);`, set:
   ```cpp
   config.debug = debug;
   ```
4. Add `--debug` to `printUsage()`:
   ```cpp
   std::cout << "  --debug               Enable debug/trace output on stderr\n";
   ```
5. In the preliminary pass (the first `for` loop), also detect `--debug` so it does not fall through to the "Unknown option" error:
   ```cpp
   } else if (strcmp(argv[i], "--debug") == 0) {
       // consumed in main parse loop
   }
   ```
   — **or** simply remove the preliminary pass restriction and handle it solely in the main loop (both approaches work; matching the existing two-pass style is safest).

### Step 8 — Fix `ScenarioSimulation.cpp`
1. After `WallFollower controller;` is declared, add:
   ```cpp
   controller.setDebug(config.debug);
   ```

### Step 9 — Remove `hasWall` and `isWallBetween` from `Maze.h`
1. Delete the two declaration lines:
   ```cpp
   bool hasWall(double x_cm, double y_cm, int direction) const;
   bool isWallBetween(double x1_cm, double y1_cm, double x2_cm, double y2_cm) const;
   ```
   Rationale: a `grep` of all `.cpp` and `.h` files confirms zero callers. Removing the declarations eliminates the link error that would occur if the symbols were ever referenced, and leaves the interface clean.

### Step 10 — Final build verification
1. Run `cmake -B build && cmake --build build -- -Wall` and confirm zero warnings and zero errors.
2. Run `./build/SimulationPathFinder --scenario straight_tunnel` and confirm no debug flood on stdout.
3. Run `./build/SimulationPathFinder --debug --scenario straight_tunnel 2>/tmp/dbg.txt && grep -q "wall" /tmp/dbg.txt` to confirm debug output goes to stderr.
4. Run `./build/SimulationPathFinder --headless --batch 5` to confirm batch mode is unaffected.

---

## Test Strategy

### New tests to add
The project has no automated unit-test framework wired into CMake. The existing tests are shell scripts (`test.sh`, `run_test.sh`, `verify_fix.sh`) that build and run the binary.

- **`run_test.sh`** — already exercises headless batch mode; ensure it still passes.
- **`verify_fix.sh`** — exercises scenario mode; ensure it still passes.
- **New manual checks** (add to `verify_fix.sh` or a new `test_debug.sh`):
  1. `--debug` off by default: `./SimulationPathFinder --scenario straight_tunnel 2>/tmp/err.txt && test ! -s /tmp/err.txt` (stderr should be empty without `--debug`).
  2. `--debug` on: `./SimulationPathFinder --debug --scenario straight_tunnel 2>/tmp/err.txt && grep -q "wall\|RECOVERY\|FOLLOW" /tmp/err.txt`.
  3. Batch mode: `./SimulationPathFinder --headless --batch 3` exits with code 0.

### Existing tests affected
- `test.sh` / `run_test.sh` / `verify_fix.sh` — should all continue to pass. The only behavioural change visible to callers is:
  - Stdout is quieter in normal mode (step-logging removed from stdout).
  - `config.json` physical values changed (`robot_radius_cm` 15→10); this affects robot collision margins in batch runs but does not break any script assertions (scripts check exit code, not metric values).

---

## Risks and Edge Cases

| Risk | Mitigation |
|---|---|
| `WallFollower.cpp` uses `extern Config config;` (global) — `minimum_distance_to_wall` must be present on that global | The global `Config config` in `main.cpp` is always populated via `Config::loadFromFile()`, which now loads the new field. No risk as long as the JSON key is present. |
| `config.json` missing `minimum_distance_to_wall` in older checked-out trees | Step 1 adds it; any build from the patched tree will have it. Old binaries running against old configs would throw a JSON key-not-found exception — acceptable since we own the config file. |
| `robot_radius_cm` 15→10 changes wall-following thresholds in `WallFollower.cpp` | The proportional safe-distance logic (`config.robot_radius_cm + config.minimum_distance_to_wall`) evaluates to `10 + 10 = 20 cm`, slightly less than the previous `15 + 10 = 25 cm`. This is a deliberate part of the spec (smaller robot needs less clearance). The CLAUDE.md wall-follower parameters remain unchanged. |
| `Simulation.cpp` step-logging currently always fires (`should_log` logic is non-trivial) | Gating on `config.debug` wraps the entire block — existing `should_log` logic is preserved inside the guard, so it still provides selective logging when debug IS enabled. |
| Removing `hasWall`/`isWallBetween` could break future code | The spec explicitly permits removal when no callers exist. A grep confirms zero callers. If future code needs these methods, they can be re-added with implementations at that time. |
| `--debug` in the preliminary argv pass | The preliminary pass only sets `run_scenario`/`run_suite` flags and ignores all other args. Adding `--debug` to the main parse loop is sufficient; the preliminary pass will fall through to the "Unknown option" branch only if `--debug` appears before a `--scenario` arg and the arg is not handled. To be safe, add a no-op case for `--debug` in the preliminary pass too. |
| `BatchSimulation` does not accept `Config.debug` — WallFollower is constructed inside `Simulation` | `Simulation`'s constructor already reads `config.debug` (after Step 6), so `BatchSimulation` creates `Simulation(config)` and the debug flag propagates automatically. No changes needed in `BatchSimulation.cpp`. |
