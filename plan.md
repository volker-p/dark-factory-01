# Implementation Plan: Physical Configuration Consolidation & Debug Control

## Goal

Eliminate all hard-coded physical constants by making `config.json` the single
source of truth, add a `--debug` CLI flag to control debug output globally,
improve `WallFollower` per spec, and complete the `Maze` interface by removing
the unimplemented `hasWall`/`isWallBetween` declarations (no callers exist).

---

## Files to Change

| File | What changes and why |
|---|---|
| `config.json` | Set `robot.radius_cm=10`, add `robot.minimum_distance_to_wall=10`; `cell_size_cm` is already 50 — verify and keep |
| `include/Config.h` | Add `double minimum_distance_to_wall_cm` field so all components can read it from Config |
| `src/Config.cpp` | Load `minimum_distance_to_wall` from `config.json` robot section |
| `include/WallFollower.h` | Change `debug_ = true` → `false`; add public `void setDebug(bool d)` method |
| `src/WallFollower.cpp` | Route all `std::cout` debug output to `std::cerr`; remove `extern Config config` global and replace with passed `minimum_distance_to_wall_cm` parameter or use the already-passed value; fix wasteful patterns (unnecessary `right_mean` alias copy) |
| `src/Simulation.cpp` | After constructing `WallFollower`, call `controller->setDebug(debug_mode)` where `debug_mode` comes from Config; remove/gate unconditional `std::cout` step-logging behind the debug flag; remove `extern Config config` usage in WallFollower by passing needed values |
| `main.cpp` | Parse `--debug` flag; store in a field or pass via Config; wire to `ScenarioSimulation` and `Simulation` |
| `include/Maze.h` | Remove the two unimplemented declarations: `hasWall` and `isWallBetween` |
| `src/Maze.cpp` | No implementation needed for removed methods (no callers exist) |
| `include/ScenarioSimulation.h` | No structural change needed; uses `Config` already |
| `src/ScenarioSimulation.cpp` | Already reads `config.cell_size_cm` — verify no hard-coded literal remains (currently correct); use `config.minimum_distance_to_wall_cm` if needed for clearance thresholds |

---

## Implementation Checklist

### Step 1 — Update `config.json`

1. Open `config.json`.
2. In the `"robot"` section, confirm `cell_size_cm` in `"maze"` is already `50` ✓.
3. Change `"radius_cm"` from `15` to `10`.
4. Add a new field `"minimum_distance_to_wall": 10` inside the `"robot"` section.

### Step 2 — Add `minimum_distance_to_wall_cm` to `Config.h`

1. Open `include/Config.h`.
2. Under the `// Robot configuration` block, add:
   ```cpp
   double minimum_distance_to_wall_cm;
   ```

### Step 3 — Load the new field in `Config.cpp`

1. Open `src/Config.cpp`.
2. After the line that loads `config.robot_radius_cm`, add:
   ```cpp
   config.minimum_distance_to_wall_cm = j["robot"]["minimum_distance_to_wall"];
   ```

### Step 4 — Add `debug` field to `Config.h` (runtime flag)

1. In `include/Config.h`, add a `bool` member for the debug flag (defaulting to
   `false`) so it can be threaded to all components via the Config object:
   ```cpp
   bool debug = false;
   ```
   Place it at the bottom of the struct, below the rendering section.

### Step 5 — Parse `--debug` in `main.cpp`

1. Open `main.cpp`.
2. In the argument-parsing loop, add a branch:
   ```cpp
   } else if (strcmp(argv[i], "--debug") == 0) {
       // will apply after config is loaded
       debug_flag = true;
   }
   ```
3. Declare `bool debug_flag = false;` near the other flag variables at the top of
   `main()`.
4. After the config is loaded (after `config = Config::loadFromFile(...)`), set:
   ```cpp
   if (debug_flag) config.debug = true;
   ```
5. Update `printUsage()` to document the new flag.

### Step 6 — Update `WallFollower.h`

1. Open `include/WallFollower.h`.
2. Change the default member initialiser from `debug_ = true` to `debug_ = false`.
3. Add the public method in the public section:
   ```cpp
   void setDebug(bool d) { debug_ = d; }
   ```

### Step 7 — Update `WallFollower.cpp`

1. Open `src/WallFollower.cpp`.
2. Remove the line `extern Config config;` at the top — this global is used only
   for `config.robot_radius_cm` in the proportional controller.  Instead, replace
   the two usages of `config.robot_radius_cm` in `computeVelocity()` with
   `config.robot_radius_cm` → read the value from a parameter or a stored member.
   The cleanest approach: store `double robot_radius_cm_` in the class, initialized
   via the constructor parameter, or pass it explicitly.
   - Add `double robot_radius_cm_ = 15.0;` as a private member in `WallFollower.h`.
   - Add a constructor overload or modify the existing constructor to accept
     `double robot_radius_cm = 15.0` and store it.
   - Replace `config.robot_radius_cm` occurrences in `WallFollower.cpp` with
     `robot_radius_cm_`.
   - Remove the `extern Config config;` line entirely.
3. Replace every `std::cout` debug print with `std::cerr`. There are approximately
   20 such calls. Use find-and-replace within the file. Do not change the message
   text, only the stream.
4. Fix the wasteful `right_mean` alias:
   - `double right_mean = right_side;` is an unnecessary copy — replace all
     subsequent uses of `right_mean` with `right_side` directly, or keep the alias
     but mark it as a const reference. Since `right_side` is already a `double`
     value copy this is minor; replacing the alias is cleaner.

### Step 8 — Wire debug flag in `Simulation.cpp`

1. Open `src/Simulation.cpp`.
2. In `Simulation::Simulation()` constructor (or at the start of `run()`), after
   creating the `WallFollower` controller, add:
   ```cpp
   controller->setDebug(config.debug);
   ```
3. The verbose unconditional `std::cout` step-logging block (lines ~172–259) in
   `Simulation::run()` currently prints every 5 steps unconditionally. Gate this
   entire block behind `config.debug`:
   ```cpp
   if (config.debug && should_log) {
       // ... existing logging block ...
   }
   ```
4. Also gate the two `std::cout` calls in `initializeRobot()` behind `config.debug`.
5. The termination-condition prints ("Maze completion threshold reached!", "Robot
   stuck, terminating simulation.") and the final summary print can remain
   unconditional — they are not debug flood.

### Step 9 — Wire debug flag in `ScenarioSimulation.cpp`

1. Open `src/ScenarioSimulation.cpp`.
2. After `WallFollower controller;`, call:
   ```cpp
   controller.setDebug(config.debug);
   ```

### Step 10 — Remove `hasWall` / `isWallBetween` from `Maze.h`

1. Open `include/Maze.h`.
2. Remove the two lines:
   ```cpp
   bool hasWall(double x_cm, double y_cm, int direction) const;
   bool isWallBetween(double x1_cm, double y1_cm, double x2_cm, double y2_cm) const;
   ```
   Confirmed: no caller exists anywhere in the codebase (grep shows declarations
   only). Removing them resolves the link-error risk and cleans the interface.
3. No change needed in `Maze.cpp`.

### Step 11 — Build and verify zero `-Wall` warnings

1. Run `cmake -B build && cmake --build build 2>&1 | grep -E "warning:|error:"`.
2. Address any remaining warnings (likely unused-variable if `right_mean` alias is
   kept or if the `extern Config config` removal leaves a dangling reference).

---

## Test Strategy

### What to add

No new test framework exists in the repository; verification is via CLI invocation
and grep-based output assertion (as specified in the spec Verification section).

The `run-tests.sh` script covers all five verification steps:

1. **Build succeeds with zero warnings** — cmake configure + build, capture
   stderr, assert no `warning:` lines.
2. **`--scenario straight_tunnel`** — run headless, assert output contains
   `Traversal success` and `Collisions` line; also assert that stderr (debug
   output) is empty/absent when `--debug` is not given.
3. **`--scenario-suite`** — run headless, assert tabular header is present
   (`SCENARIO`, `SUCCESS`, `COLLISIONS`), assert no WallFollower debug noise on
   stdout.
4. **`--debug --scenario straight_tunnel`** — redirect stderr to a file, assert it
   contains the word `wall` (WallFollower state-transition messages).
5. **`--headless --batch 5`** — assert output contains `Batch complete` or
   `successful`.

### Existing behaviour to protect

- `ScenarioSimulation::runScenario` already reads `config.cell_size_cm` — no
  regression there, but changing `robot_radius_cm` from 15→10 and using
  `minimum_distance_to_wall_cm=10` will change numeric threshold values in
  `Simulation.cpp` (front_threshold) and `ScenarioSimulation.cpp`. These are
  computed as `config.robot_radius_cm + 20.0` = 30 cm with new values instead of
  35 cm. This is intentional and expected to improve navigation in the corridor
  (robot now 10 cm radius in 50 cm cell — plenty of room).
- `BatchResults` struct and `saveSummary()` signature must not change (spec
  constraint).
- The `extern Config config` global is used by both `WallFollower.cpp` and
  `Renderer.cpp`. Removing it from `WallFollower.cpp` requires adding a member
  field. `Renderer.cpp` still needs the global and must not be changed.

---

## Risks and Edge Cases

| Risk | Mitigation |
|---|---|
| `extern Config config` global still required by `Renderer.cpp` | Only remove it from `WallFollower.cpp`; keep the global declaration in `main.cpp` and `extern` in `Renderer.cpp` |
| Changing `robot_radius_cm` from 15 → 10 shifts `front_threshold` from 35 to 30 cm in `Simulation.cpp` and `ScenarioSimulation.cpp` | The new value (30 cm) is intentional; WallFollower proportional controller uses its own internal constants (inner/outer radius) not tied to robot_radius_cm — no algorithm change required |
| `WallFollower.cpp` uses `config.robot_radius_cm` in two places in `computeVelocity()` | Must add `robot_radius_cm_` member and remove `extern` dependency; failure to do so leaves a linker/ODR issue if the global is ever removed |
| `right_mean` alias removal: `right_mean` appears ~10 times in `WallFollower.cpp` | Replace all occurrences with `right_side` — ensure no regression in the proportional controller formula |
| `minimum_distance_to_wall` field missing from `Config::validate()` | Not strictly needed for validation (it has no natural minimum constraint), but worth documenting |
| Debug output previously on stdout (WallFollower) mixed with tabular scenario output | After fix, WallFollower sends to stderr; `--scenario-suite` stdout will be clean tabular output even with `--debug` |
| `config.json` `minimum_distance_to_wall` key name must match what `Config.cpp` reads | Use consistent key `"minimum_distance_to_wall"` in JSON and C++ loader |
| `-Wall` warnings from removed `right_mean` unused-alias | Clean up alias completely or ensure it's used |
