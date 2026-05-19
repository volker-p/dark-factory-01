<!-- op_work_package_id: none -->
---
target_repo: volker-p/SimulationPathFinder
target_branch: master
type: feature
---

# Sensor Config & Trajectory Tracing

## Background

The robot has a single front-facing distance sensor. To sense other directions it
stops, rotates to the measurement angle, reads, then rotates back to the drive
heading. `WallFollower::update()` currently hardcodes exactly two scan angles —
left (`current_heading + PI/2`) and right (`current_heading - PI/2`). A user
cannot change the number or angles of scans without editing C++ source.

Additionally, when a scenario test fails the fix agent sees only aggregate metrics
(min clearance, collision count) and build output — not where the robot was, what
each sensor read, or what decision it made. A human watching the robot would
immediately see all of this.

This spec fixes both problems.

---

## Requirements

### R1 — Config field: `wall_scan_angles_deg`

Add one field to `Config`:

```cpp
std::vector<double> wall_scan_angles_deg;   // degrees, relative to current heading
```

**Location:** `include/Config.h`, after `angle_tolerance_rad` in the
wall-follower block.

**Default:** `{-90.0, 90.0}` — preserves the current two-sensor behaviour (right
then left).

**Parsing in `src/Config.cpp`:** use `.value()` with the default vector:

```cpp
config.wall_scan_angles_deg = j.value(
    "wall_scan_angles_deg",
    std::vector<double>{-90.0, 90.0}
);
```

**Validation:** add a guard in `Config::validate()`:

```cpp
if (wall_scan_angles_deg.empty()) {
    std::cerr << "Error: wall_scan_angles_deg must not be empty\n";
    return false;
}
```

Do **not** modify `config.json` — the default applies when the key is absent.

---

### R2 — WallFollower: configurable scan loop

#### R2a — Structs and getters

Add the following to `include/WallFollower.h` (public section):

```cpp
struct ScanResult {
    double angle_deg;     // entry from wall_scan_angles_deg
    double distance_cm;   // raw sensor reading, no noise
};

struct DecisionInfo {
    enum class Kind { TUNNEL, RIGHT_WALL, LEFT_WALL, NO_WALL } kind;
    double wall_left_dist_cm;    // distance to leftmost-angle detected wall; inf if none
    double wall_right_dist_cm;   // distance to rightmost-angle detected wall; inf if none
    double correction_rad;       // clamped heading correction applied
    double new_heading_rad;      // absolute heading after correction, normalised to [0, 2π)
};

const std::vector<ScanResult>& getLastScanResults() const { return last_scan_results_; }
const DecisionInfo& getLastDecision() const { return last_decision_; }
```

Add private members:

```cpp
std::vector<ScanResult> last_scan_results_;
DecisionInfo last_decision_{};
```

#### R2b — Replace hardcoded scan pair with a loop

In `src/WallFollower.cpp`, remove the existing two-rotation block (rotate left →
read → rotate right → read) and the `scanReading()` helper. Replace with:

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

After the loop, rotate back to `current_heading_rad_` before the
heading-correction step (or proceed directly if the correction step rotates
anyway — match whatever the existing code does after reading).

#### R2c — Generalised tunnel-centring

After the scan loop, identify the leftmost and rightmost walls:

```
left_wall  = entry in last_scan_results_ with the most-positive angle_deg
             where distance_cm < cfg_.sensor_range_cm
right_wall = entry in last_scan_results_ with the most-negative angle_deg
             where distance_cm < cfg_.sensor_range_cm
```

Use `std::numeric_limits<double>::infinity()` when no wall is found on a side.
A sensor at exactly 0° contributes no lateral information and is correctly
ignored by this selection.

Apply the existing R4/R5 logic using those two values:

| Walls detected | Formula |
|---|---|
| Both | `error = dist_right − dist_left`<br>`correction = clamp(kp * error, −π/4, π/4)`<br>`new_heading = normalise(current + correction)` |
| Right only | `correction = kp * (dist_right − wall_target_distance_cm)`<br>`new_heading = normalise(current − correction)` |
| Left only | `correction = kp * (dist_left − wall_target_distance_cm)`<br>`new_heading = normalise(current + correction)` |
| Neither | `new_heading = current_heading_rad_` |

Populate `last_decision_` before the drive step:

```cpp
last_decision_ = {kind, dist_left, dist_right, correction, new_heading};
```

---

### R3 — Trace CSV schema

The trace file is a standard CSV with a header row. The number of sensor columns
is variable, determined at runtime from `cfg_.wall_scan_angles_deg.size()`.

#### Header format

```
step,x_cm,y_cm,heading_deg,cell_x,cell_y,<sensor columns>,decision,wall_left_dist_cm,wall_right_dist_cm,correction_rad,new_heading_deg,collided
```

Sensor columns are named `sensor_<N>_angle_<A>_cm` where `N` is the zero-based
index in `wall_scan_angles_deg` and `A` is the angle formatted as a signed
integer (e.g. `-90`, `90`, `0`, `45`).

**Example — default config `[-90.0, 90.0]`:**

```
step,x_cm,y_cm,heading_deg,cell_x,cell_y,sensor_0_angle_-90_cm,sensor_1_angle_90_cm,decision,wall_left_dist_cm,wall_right_dist_cm,correction_rad,new_heading_deg,collided
```

#### Column definitions

| Column | Format | Description |
|---|---|---|
| `step` | int | Loop step counter, 0-based; resets to 0 per scenario in suite runs |
| `x_cm` | float, 2 d.p. | Robot X position **before** `controller.update()` |
| `y_cm` | float, 2 d.p. | Robot Y position **before** `controller.update()` |
| `heading_deg` | float, 1 d.p. | Robot heading before update, range [0, 360) |
| `cell_x` | int | `floor(x_cm / cell_size_cm)` |
| `cell_y` | int | `floor(y_cm / cell_size_cm)` |
| `sensor_N_angle_A_cm` | float, 2 d.p. | Raw distance reading; write `inf` when no wall detected |
| `decision` | string | One of: `TUNNEL`, `RIGHT_WALL`, `LEFT_WALL`, `NO_WALL` |
| `wall_left_dist_cm` | float, 2 d.p. | Leftmost detected wall distance; `inf` if none |
| `wall_right_dist_cm` | float, 2 d.p. | Rightmost detected wall distance; `inf` if none |
| `correction_rad` | float, 4 d.p. | Clamped heading correction |
| `new_heading_deg` | float, 1 d.p. | Heading after correction, range [0, 360) |
| `collided` | int | `1` if robot pose unchanged after update, else `0` |

Write `inf` (lowercase) for infinite distances — readable by Python's
`float('inf')` and pandas `read_csv`. Use `std::ofstream` with `std::fixed` and
`std::setprecision` per column. Unix line endings (`\n`).

---

### R4 — `--trace` CLI flag

#### Syntax

```
./SimulationPathFinder --scenario <name> [--trace <filepath>]
./SimulationPathFinder --scenario-suite  [--trace <filepath>]
```

`--trace` is a silent no-op if used without `--scenario` or `--scenario-suite`.
With `--scenario-suite`, all five scenarios append to one file; `step` resets
to 0 at the start of each scenario.

#### Parsing in `src/main.cpp`

In the existing argument-parsing loop:

```cpp
std::string trace_path;   // empty → no trace
...
} else if (strcmp(argv[i], "--trace") == 0 && i + 1 < argc) {
    trace_path = argv[++i];
}
```

Update `printUsage()`:

```
  --trace <filepath>    Write per-step trace CSV during --scenario / --scenario-suite runs
```

In the scenario-handling block:

```cpp
ScenarioSimulation sim(config);

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

Then pass `trace_out` to `runScenario` or `runSuite`. `ScenarioSimulation` skips
all I/O when the pointer is null.

#### `writeTraceHeader` public method on `ScenarioSimulation`

```cpp
void writeTraceHeader(std::ostream& out) const;
```

Generates the header line dynamically from `config.wall_scan_angles_deg`. Angle
columns use `static_cast<int>(std::round(angle))` for the integer suffix.

#### Updated `ScenarioSimulation` signatures

```cpp
ScenarioMetrics runScenario(ScenarioType type, std::ostream* trace_out = nullptr);
std::vector<ScenarioMetrics> runSuite(std::ostream* trace_out = nullptr);
```

#### Per-step trace writing in `runScenario`

Inside the step loop:

1. Capture `Pose before = robot.getPose()` before `controller.update()`.
2. Call `controller.update()`.
3. Capture `Pose after = robot.getPose()`; set `collided = (after.x == before.x && after.y == before.y)`.
4. If `trace_out != nullptr`, read `controller.getLastScanResults()` and `controller.getLastDecision()`, format and write one CSV row.

The sensor readings for the trace come from `getLastScanResults()` on
`WallFollower` — do **not** call `robot.getSensorReadings()` a second time.

---

### R5 — `fix.md` prompt addition

This file lives in **this repository** (dark-factory-01), not in
`SimulationPathFinder`.

Append the following block to
`.fabro/workflows/implement-spec/prompts/fix.md`, separated from the existing
last line by one blank line:

```markdown
## Scenario-test failures: use the trace

When a scenario test fails (the SUCCESS column shows `NO`, or the binary exits
non-zero during a `--scenario` run), generate a trajectory trace before
attempting any fix:

```bash
cd target-repo
./cmake-build-debug/SimulationPathFinder \
    --scenario <failing_scenario_name> \
    --trace /tmp/trace_<scenario>.csv
```

Use the lowercase-underscore form of the scenario name (e.g. `straight_tunnel`,
`corner_right`). If the suite as a whole fails, run each failing scenario
individually.

Then read the trace:

```bash
# First collision step
grep ",1$" /tmp/trace_<scenario>.csv | head -5

# First step where robot lost all walls
grep ",NO_WALL," /tmp/trace_<scenario>.csv | head -5

# 10 steps around the first collision
FIRST=$(grep -n ",1$" /tmp/trace_<scenario>.csv | head -1 | cut -d: -f1)
sed -n "$((FIRST-5)),$((FIRST+5))p" /tmp/trace_<scenario>.csv
```

Include your findings in the fix: what step the problem first appeared, what
sensor readings and decision were made at that step, and what the root cause is.
Do not guess — trace through the CSV and the code logic before changing anything.
```

---

## Files to change

| File | Change |
|------|--------|
| `include/Config.h` | Add `wall_scan_angles_deg` field |
| `src/Config.cpp` | Parse with default `{-90.0, 90.0}`; validate non-empty |
| `include/WallFollower.h` | Add `ScanResult`, `DecisionInfo` structs; add getters and private members |
| `src/WallFollower.cpp` | Replace hardcoded scan pair with configurable loop; remove `scanReading()`; populate `last_scan_results_` and `last_decision_` |
| `include/ScenarioSimulation.h` | Add `writeTraceHeader`; update `runScenario`/`runSuite` signatures |
| `src/ScenarioSimulation.cpp` | Implement `writeTraceHeader`; add per-step trace writing in `runScenario` |
| `src/main.cpp` | Parse `--trace`; open file; call `writeTraceHeader`; pass stream pointer |
| `.fabro/workflows/implement-spec/prompts/fix.md` | Append trace-usage block (in dark-factory-01, not target-repo) |

---

## Constraints

- C++20; match existing style: PascalCase classes, `snake_case_` private members.
- Build must produce zero `-Wall -Wextra` warnings.
- Do not modify `config.json`.
- Do not modify files in `common/`, `external/`, or `firmware/`.
- Do not change `BatchSimulation`, `Simulation`, `Renderer`, `DataLogger`, or
  `PerformanceMetrics` — tracing is exclusive to scenario runs.
- `--trace` without `--scenario`/`--scenario-suite` must be silent (no error, no
  output file created).
- Existing `--scenario` / `--scenario-suite` behaviour without `--trace` must be
  bit-for-bit identical to before.

---

## Verification

```bash
# 1. Clean build — zero warnings
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug
cmake --build build -- CXXFLAGS="-Wall -Wextra"
echo "--- BUILD SUCCEEDED ---"

# 2. Suite still works unchanged
./build/SimulationPathFinder --scenario-suite > /tmp/suite.txt
grep -q "STRAIGHT_TUNNEL" /tmp/suite.txt || { echo "FAIL: suite output missing"; exit 1; }
echo "--- SUITE OK ---"

# 3. Single scenario with trace creates the file
./build/SimulationPathFinder --scenario straight_tunnel --trace /tmp/t.csv
test -f /tmp/t.csv || { echo "FAIL: trace file not created"; exit 1; }

# 4. Header — fixed columns
head -1 /tmp/t.csv | grep -q "step,x_cm,y_cm,heading_deg,cell_x,cell_y" \
    || { echo "FAIL: header missing fixed columns"; exit 1; }

# 5. Header — default sensor columns
head -1 /tmp/t.csv | grep -q "sensor_0_angle_-90_cm" \
    || { echo "FAIL: sensor_0 column missing"; exit 1; }
head -1 /tmp/t.csv | grep -q "sensor_1_angle_90_cm" \
    || { echo "FAIL: sensor_1 column missing"; exit 1; }

# 6. Header — decision columns
head -1 /tmp/t.csv | grep -q "decision,wall_left_dist_cm,wall_right_dist_cm,correction_rad,new_heading_deg,collided" \
    || { echo "FAIL: header missing decision columns"; exit 1; }

# 7. At least one data row
[ "$(wc -l < /tmp/t.csv)" -ge 2 ] || { echo "FAIL: trace has no data rows"; exit 1; }

# 8. collided column is only 0 or 1
tail -n +2 /tmp/t.csv | awk -F',' '{print $NF}' | grep -qvE '^[01]$' \
    && { echo "FAIL: collided column has non-0/1 values"; exit 1; } || true

# 9. Suite trace works
./build/SimulationPathFinder --scenario-suite --trace /tmp/suite_trace.csv
test -f /tmp/suite_trace.csv || { echo "FAIL: suite trace file not created"; exit 1; }

# 10. --trace without --scenario is silent
./build/SimulationPathFinder --headless --batch 1 --trace /tmp/ignored.csv > /dev/null 2>&1
echo "--- TRACE FLAG OK ---"

# 11. Headless batch unbroken
./build/SimulationPathFinder --headless --batch 3 > /dev/null
echo "--- ALL VERIFICATIONS PASSED ---"
```
