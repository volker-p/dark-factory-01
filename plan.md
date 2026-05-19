# Implementation Plan: Sensor Config & Trajectory Tracing

## Goal

Add a configurable `wall_scan_angles_deg` field to `Config`, replace the hardcoded two-angle scan loop in `WallFollower` with a data-driven loop that records scan and decision state, implement a `--trace` CSV flag in `ScenarioSimulation`/`main.cpp`, and append the trace-usage block to the `fix.md` prompt in dark-factory-01.

---

## Files to Change

| File | What changes and why |
|---|---|
| `target-repo/include/Config.h` | Add `std::vector<double> wall_scan_angles_deg` field in the wall-follower parameter block, after `angle_tolerance_rad` |
| `target-repo/src/Config.cpp` | Parse `wall_scan_angles_deg` with `.value()` defaulting to `{-90.0, 90.0}`; add non-empty validation guard in `Config::validate()` |
| `target-repo/include/WallFollower.h` | Add `ScanResult` and `DecisionInfo` public structs; add `getLastScanResults()` and `getLastDecision()` getters; add `last_scan_results_` and `last_decision_` private members |
| `target-repo/src/WallFollower.cpp` | Remove `scanReading()` helper and the hardcoded left/right two-rotation block; replace with a `for`-loop over `cfg_.wall_scan_angles_deg`; after the loop identify leftmost/rightmost walls; apply existing heading correction logic; populate `last_scan_results_` and `last_decision_` before the drive step |
| `target-repo/include/ScenarioSimulation.h` | Add `writeTraceHeader(std::ostream&) const` public method; change `runScenario` and `runSuite` signatures to accept `std::ostream* trace_out = nullptr` |
| `target-repo/src/ScenarioSimulation.cpp` | Implement `writeTraceHeader` (dynamic header from `wall_scan_angles_deg`); add trace-write logic inside `runScenario` step loop (capture before/after pose, read `getLastScanResults()` / `getLastDecision()`, format CSV row); update `runSuite` to pass `trace_out` through to each `runScenario` call and reset `step` counter per scenario |
| `target-repo/src/main.cpp` | Declare `trace_path` string; parse `--trace <filepath>` in the argument-parsing loop (skip silently if not in scenario/suite mode); update `printUsage()`; open `std::ofstream`, call `sim.writeTraceHeader()`, pass `trace_out` to `runScenario` / `runSuite` |
| `.fabro/workflows/implement-spec/prompts/fix.md` | Verify / append the trace-usage block — the block already appears to be present in the current file; no change needed if it's already there; otherwise append it |

---

## Implementation Checklist

### 1 — `include/Config.h`

1. Open `include/Config.h`.
2. After the line `double angle_tolerance_rad = 0.05;` (inside the "Wall follower algorithm parameters" block), add:
   ```cpp
   std::vector<double> wall_scan_angles_deg;   // degrees, relative to current heading
   ```
3. No other changes to this file.

---

### 2 — `src/Config.cpp`

4. In `Config::loadFromFile`, after the line that parses `angle_tolerance_rad`, add:
   ```cpp
   config.wall_scan_angles_deg = j.value(
       "wall_scan_angles_deg",
       std::vector<double>{-90.0, 90.0}
   );
   ```
5. In `Config::validate()`, at the end of the validation checks (before `return true`), add:
   ```cpp
   if (wall_scan_angles_deg.empty()) {
       std::cerr << "Error: wall_scan_angles_deg must not be empty\n";
       return false;
   }
   ```
6. Do **not** modify `config.json`.

---

### 3 — `include/WallFollower.h`

7. Add `#include <vector>` at the top if not already present (it is not currently included).
8. In the `public` section (before or after the `update` declaration), add the two structs and two getters:
   ```cpp
   struct ScanResult {
       double angle_deg;
       double distance_cm;
   };

   struct DecisionInfo {
       enum class Kind { TUNNEL, RIGHT_WALL, LEFT_WALL, NO_WALL } kind;
       double wall_left_dist_cm;
       double wall_right_dist_cm;
       double correction_rad;
       double new_heading_rad;
   };

   const std::vector<ScanResult>& getLastScanResults() const { return last_scan_results_; }
   const DecisionInfo& getLastDecision() const { return last_decision_; }
   ```
9. In the `private` section, add:
   ```cpp
   std::vector<ScanResult> last_scan_results_;
   DecisionInfo last_decision_{};
   ```

---

### 4 — `src/WallFollower.cpp`

10. Remove the `scanReading()` static helper function entirely (it will not be called after the refactor).

11. Inside `WallFollower::update()`, remove the existing Steps 2–5 block (the two `rotateToHeading` + `getSensorReadings` calls for `left_angle` / `right_angle` / `dist_left` / `dist_right`).

12. Replace with the configurable scan loop:
    ```cpp
    last_scan_results_.clear();
    last_scan_results_.reserve(cfg_.wall_scan_angles_deg.size());

    for (double angle_deg : cfg_.wall_scan_angles_deg) {
        double target = normalise(current_heading_rad_ + angle_deg * M_PI / 180.0);
        rotateToHeading(robot, maze, target);
        auto readings = robot.getSensorReadings(maze, /*with_noise=*/false);
        last_scan_results_.push_back({angle_deg, readings[0]});
    }
    ```
    Note: `readings[0]` is the front-facing sensor (the only sensor when `config.json` has `"angles_deg": [0]`). This captures what the front sensor sees after the robot has rotated to the scan direction, giving the distance in that scan direction.

13. After the scan loop, identify leftmost and rightmost walls (angles relative to current heading — most-positive = leftmost, most-negative = rightmost):
    ```cpp
    double dist_left  = std::numeric_limits<double>::infinity();
    double dist_right = std::numeric_limits<double>::infinity();

    // Leftmost: highest angle_deg with detection
    // Rightmost: lowest angle_deg with detection
    const ScanResult* left_entry  = nullptr;
    const ScanResult* right_entry = nullptr;

    for (const auto& sr : last_scan_results_) {
        if (sr.distance_cm < cfg_.sensor_range_cm) {
            if (!left_entry  || sr.angle_deg > left_entry->angle_deg)  left_entry  = &sr;
            if (!right_entry || sr.angle_deg < right_entry->angle_deg) right_entry = &sr;
        }
    }
    if (left_entry)  dist_left  = left_entry->distance_cm;
    if (right_entry) dist_right = right_entry->distance_cm;
    ```

14. Apply the heading-correction logic using `dist_left`/`dist_right` (same as the existing R4/R5 logic):
    ```cpp
    bool left_detected  = !std::isinf(dist_left);
    bool right_detected = !std::isinf(dist_right);

    DecisionInfo::Kind kind;
    double correction = 0.0;
    double new_heading;

    if (left_detected && right_detected) {
        kind = DecisionInfo::Kind::TUNNEL;
        double error = dist_right - dist_left;
        correction   = clamp(cfg_.wall_follow_kp * error, -PI / 4.0, PI / 4.0);
        new_heading  = normalise(current_heading_rad_ + correction);
    } else if (right_detected) {
        kind = DecisionInfo::Kind::RIGHT_WALL;
        correction  = cfg_.wall_follow_kp * (dist_right - cfg_.wall_target_distance_cm);
        new_heading = normalise(current_heading_rad_ - correction);
    } else if (left_detected) {
        kind = DecisionInfo::Kind::LEFT_WALL;
        correction  = cfg_.wall_follow_kp * (dist_left - cfg_.wall_target_distance_cm);
        new_heading = normalise(current_heading_rad_ + correction);
    } else {
        kind = DecisionInfo::Kind::NO_WALL;
        correction  = 0.0;
        new_heading = current_heading_rad_;
    }

    last_decision_ = {kind, dist_left, dist_right, correction, new_heading};
    ```

15. Keep the existing drive step unchanged (rotate to `new_heading`, then `robot.update()` with forward velocity).

16. Add `#include <limits>` to `WallFollower.cpp` (needed for `std::numeric_limits`). Replace the existing `static constexpr double PI` with or alongside a `#include <cmath>` usage of `M_PI` — or keep the local `PI` constant and use it in the scan loop. The spec uses `M_PI`; use whichever is consistent with the file (current file uses local `PI`; use that and replace `M_PI` in step 12 with `PI`).

---

### 5 — `include/ScenarioSimulation.h`

17. Add `#include <ostream>` (or `#include <fstream>`) at the top if not present.
18. Change `runScenario` declaration to:
    ```cpp
    ScenarioMetrics runScenario(ScenarioType type, std::ostream* trace_out = nullptr);
    ```
19. Change `runSuite` declaration to:
    ```cpp
    std::vector<ScenarioMetrics> runSuite(std::ostream* trace_out = nullptr);
    ```
20. Add `writeTraceHeader` public method:
    ```cpp
    void writeTraceHeader(std::ostream& out) const;
    ```

---

### 6 — `src/ScenarioSimulation.cpp`

21. Add includes at the top:
    ```cpp
    #include <ostream>
    #include <iomanip>
    #include <cmath>
    #include "WallFollower.h"
    ```
    (`WallFollower.h` is needed for `ScanResult`, `DecisionInfo`, and the getter access on the `controller` object — and it is already indirectly used via `WallFollower controller(config)`, but the header must be explicitly included for the structs.)

22. Implement `writeTraceHeader`:
    ```cpp
    void ScenarioSimulation::writeTraceHeader(std::ostream& out) const {
        out << "step,x_cm,y_cm,heading_deg,cell_x,cell_y";
        for (std::size_t i = 0; i < config.wall_scan_angles_deg.size(); ++i) {
            int a = static_cast<int>(std::round(config.wall_scan_angles_deg[i]));
            out << ",sensor_" << i << "_angle_" << a << "_cm";
        }
        out << ",decision,wall_left_dist_cm,wall_right_dist_cm"
               ",correction_rad,new_heading_deg,collided\n";
    }
    ```

23. In `runScenario`, change the signature to accept `std::ostream* trace_out = nullptr`.

24. Inside the step loop, add a local `step` counter (initialized to 0 before the loop, incremented after each write — this is distinct from `m.steps_taken`):
    ```cpp
    int step = 0;
    for (int i = 0; i < config.max_steps; i++, step++) {
        ...
    ```

25. Before `controller.update(robot, maze)`, capture `Pose before = robot.getPose();`.
    (Note: `before` is already captured in the existing loop as `before` for collision counting — reuse it.)

26. After `controller.update(robot, maze)`, capture `Pose after = robot.getPose()` and compute `int collided = (after.x_cm == before.x_cm && after.y_cm == before.y_cm) ? 1 : 0;`.
    (The existing code already captures `before`/`after` and counts collisions — align with that pattern.)

27. After the update, if `trace_out != nullptr`, write the trace row:
    ```cpp
    if (trace_out) {
        const auto& scans    = controller.getLastScanResults();
        const auto& decision = controller.getLastDecision();

        // Determine decision string
        const char* decision_str = "";
        switch (decision.kind) {
            case WallFollower::DecisionInfo::Kind::TUNNEL:     decision_str = "TUNNEL";     break;
            case WallFollower::DecisionInfo::Kind::RIGHT_WALL: decision_str = "RIGHT_WALL"; break;
            case WallFollower::DecisionInfo::Kind::LEFT_WALL:  decision_str = "LEFT_WALL";  break;
            case WallFollower::DecisionInfo::Kind::NO_WALL:    decision_str = "NO_WALL";    break;
        }

        auto fmt_dist = [](std::ostream& os, double d) {
            if (std::isinf(d)) os << "inf";
            else os << std::fixed << std::setprecision(2) << d;
        };

        *trace_out << step << ","
                   << std::fixed << std::setprecision(2) << before.x_cm << ","
                   << std::fixed << std::setprecision(2) << before.y_cm << ","
                   << std::fixed << std::setprecision(1)
                   << (before.theta_rad * 180.0 / M_PI_local) << ","  // heading_deg in [0,360)
                   << static_cast<int>(before.x_cm / config.cell_size_cm) << ","
                   << static_cast<int>(before.y_cm / config.cell_size_cm);

        for (const auto& sr : scans) {
            *trace_out << ",";
            fmt_dist(*trace_out, sr.distance_cm);
        }

        *trace_out << "," << decision_str << ",";
        fmt_dist(*trace_out, decision.wall_left_dist_cm);
        *trace_out << ",";
        fmt_dist(*trace_out, decision.wall_right_dist_cm);
        *trace_out << ","
                   << std::fixed << std::setprecision(4) << decision.correction_rad << ","
                   << std::fixed << std::setprecision(1)
                   << (decision.new_heading_rad * 180.0 / M_PI_local)
                   << "," << collided << "\n";
    }
    ```

    Key notes:
    - `heading_deg` is `before.theta_rad` converted to degrees, normalised to `[0, 360)`. Use `std::fmod(theta_rad * 180.0/PI + 360.0, 360.0)` to guarantee non-negative output.
    - `new_heading_deg` likewise from `decision.new_heading_rad` (already normalised to `[0, 2π)` by `normalise()`).
    - Use a file-local `constexpr double PI` (already present in the `.cpp`) rather than `M_PI` to avoid portability issues.
    - `inf` strings must be lowercase.

28. Update `runSuite` to accept `std::ostream* trace_out` and pass it to each `runScenario` call. The `step` counter resets to 0 at the start of each scenario automatically (since it is a local variable inside `runScenario`).

---

### 7 — `src/main.cpp`

29. Declare `std::string trace_path;` alongside the other argument variables near the top of `main`.

30. In the preliminary-pass loop (which already reads `--scenario` and `--scenario-suite`), do **not** parse `--trace` yet — we need to consume it from `argv` in the second pass to avoid the "Unknown option" error.

31. In the full argument-parsing loop, add a new `else if` branch before the final `else` (Unknown option):
    ```cpp
    } else if (strcmp(argv[i], "--trace") == 0 && i + 1 < argc) {
        trace_path = argv[++i];
    ```

32. In `printUsage()`, add a new line in the Options section:
    ```
      --trace <filepath>    Write per-step trace CSV during --scenario / --scenario-suite runs
    ```

33. In the scenario-handling block (after `ScenarioSimulation sim(config);`), add:
    ```cpp
    std::ofstream trace_file;
    std::ostream* trace_out = nullptr;

    if (!trace_path.empty()) {
        trace_file.open(trace_path);
        if (!trace_file.is_open()) {
            std::cerr << "Error: cannot open trace file: " << trace_path << "\n";
            return 1;
        }
        sim.writeTraceHeader(trace_file);
        trace_out = &trace_file;
    }
    ```
    Add `#include <fstream>` if not already present (it is not currently included in `main.cpp`).

34. Change the `runSuite()` call to `sim.runSuite(trace_out)`.
35. Change the `runScenario(type)` call to `sim.runScenario(type, trace_out)`.
36. Since `--trace` without `--scenario`/`--scenario-suite` must be silent: the `trace_path` variable is set, but the `if (run_scenario || run_suite)` block is never entered, so `trace_file.open()` is never called. The flag is silently absorbed by the second-pass loop. No extra guard needed.

---

### 8 — `.fabro/workflows/implement-spec/prompts/fix.md`

37. Read the current content. The `fix.md` already contains the trace-usage block (as seen during planning). **No change is needed** — the block was already appended in a prior commit. Verify by checking for the string `## Scenario-test failures: use the trace` in the file; if present, skip this step.

---

## Test Strategy

### Existing tests affected
- The existing `--scenario-suite` run (no `--trace`) must produce bit-for-bit identical output. Verify by running the suite and grepping for `STRAIGHT_TUNNEL`, `YES`/`NO` in the table output.
- The `--batch` / `--headless` flow must be unchanged: `WallFollower`, `Config`, and `ScenarioSimulation` changes must not touch `Simulation.cpp`, `BatchSimulation.cpp`, or `DataLogger.cpp`.

### New tests to add (in `run-tests.sh`)
1. **Build with zero warnings** — configure with `-Wall -Wextra`; check exit code.
2. **Suite still works** — `--scenario-suite > /tmp/suite.txt`; grep for `STRAIGHT_TUNNEL`.
3. **Single scenario with trace creates file** — `--scenario straight_tunnel --trace /tmp/t.csv`; `test -f /tmp/t.csv`.
4. **Header fixed columns** — `head -1 /tmp/t.csv | grep -q "step,x_cm,y_cm,heading_deg,cell_x,cell_y"`.
5. **Header default sensor columns** — grep for `sensor_0_angle_-90_cm` and `sensor_1_angle_90_cm`.
6. **Header decision columns** — grep for `decision,wall_left_dist_cm,wall_right_dist_cm,correction_rad,new_heading_deg,collided`.
7. **At least one data row** — `wc -l < /tmp/t.csv` ≥ 2.
8. **`collided` column values are only 0 or 1** — `awk -F','` on last field; fail if anything other than `0` or `1` found.
9. **Suite trace works** — `--scenario-suite --trace /tmp/suite_trace.csv`; `test -f /tmp/suite_trace.csv`.
10. **`--trace` without scenario is silent** — run with `--headless --batch 1 --trace /tmp/ignored.csv`; must not error.
11. **Headless batch unbroken** — `--headless --batch 3` must succeed.

---

## Risks and Edge Cases

| Risk | Mitigation |
|---|---|
| `config.json` has `"angles_deg": [0]` (only the front sensor). When the scan loop rotates to angle `-90°` and reads `readings[0]`, it reads the front sensor after the robot has physically rotated 90°. This is exactly what the old `scanReading()` did (it averaged `readings[0]` and `readings[1]` which were both front-area sensors). With only one sensor (`readings[0]`), the new code is correct. | Use `readings[0]` consistently — the robot's single sensor always points forward. |
| `wall_scan_angles_deg` default is `{-90.0, 90.0}` (right then left). The old code read left first then right. The order of loop iterations changes scan sequence, but the heading-correction math only depends on which entries have the highest/lowest `angle_deg`, not on iteration order. | Selection logic uses `>` and `<` comparisons on `angle_deg`, not positional index. |
| If `wall_scan_angles_deg` contains a 0° entry, it contributes no lateral info. The leftmost/rightmost selection skips it only if no wall is detected (distance ≥ `sensor_range_cm`), but if a wall is very close ahead at 0° it would pollute `dist_left` or `dist_right` depending on tie-breaking. | As the spec notes: "A sensor at exactly 0° contributes no lateral information and is correctly ignored by this selection" — this is true because it is both the most-positive-if-only-entry AND most-negative-if-only-entry for left/right. If combined with ±90° angles, the ±90° entries dominate since 90 > 0 > -90. The selection is correct. |
| The preliminary argument-parsing loop in `main.cpp` does not handle `--trace`, so if `--trace` appears before `--scenario`, the second pass will correctly consume it via `else if`. However, if `--trace` appears in the preliminary loop without a handler, the argument is not consumed there and no issue arises because the preliminary loop only sets `run_scenario` / `run_suite`. | Add `--trace` only to the second (full) parsing loop. |
| `std::ofstream` in `main.cpp` is a stack variable; it must remain in scope for the full lifetime of `runScenario`/`runSuite`. Placing it after `ScenarioSimulation sim(config)` and before the `runSuite`/`runScenario` call ensures this. | Declare `trace_file` in the same scope as the `if (run_scenario || run_suite)` block, before any scenario call. |
| `heading_deg` in the trace must be in `[0, 360)` but `theta_rad` from `getPose()` can be in `[-π, π]` or beyond. Use `std::fmod(deg + 360.0, 360.0)` to normalise. | Apply normalisation helper before writing to CSV. |
| `std::setprecision` is sticky on `std::ostream`. Each column must set its own precision before writing. Do not assume the previous column's precision persists correctly across the row. | Set `std::fixed` and `std::setprecision(N)` before each column group. |
| `-Wall -Wextra` with `DecisionInfo{}` default initialisation: the `Kind` enum may produce a "may be uninitialised" warning. | Use `DecisionInfo last_decision_{}` (value-initialises the struct including the enum to 0 which corresponds to `TUNNEL`). |
| The `ScenarioSimulation.cpp` file currently does not include `WallFollower.h` explicitly (it's pulled in transitively). The struct types `ScanResult` and `DecisionInfo` need explicit include. | Add `#include "WallFollower.h"` at the top of `ScenarioSimulation.cpp`. |
| `runSuite` resets the `step` counter per scenario naturally (it's a local in `runScenario`), matching the spec requirement. | No special handling needed; document in code comments for clarity. |
