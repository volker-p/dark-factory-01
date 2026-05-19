# Review (Round 2) — Sensor Config & Trajectory Tracing

Spec: `specs/simulation-path-finder/sensor-config-and-tracing.md`
Target: `volker-p/SimulationPathFinder` @ `master`
Branch HEAD commit: `cbab5a3` — "Add wall_scan_angles_deg config, configurable scan loop, and --trace CSV flag"

Round-1 review approved this PR; the human gate returned **Rework**. This second pass looks more critically at deviations from spec wording, gratuitous refactoring, and code-hygiene issues that the first review marked as merely cosmetic.

---

## Test Results

`bash run-tests.sh 2>&1 | tee test-output.txt; exit ${PIPESTATUS[0]}` exited **0**.

Final summary (last 20 lines of `test-output.txt`):

```
[100%] Built target SimulationPathFinder
--- BUILD SUCCEEDED ---
--- SUITE OK ---
Configuration loaded from config.json
Scenario: STRAIGHT_TUNNEL
  Traversal success : NO
  Steps taken       : 10000
  Distance (cm)     : 19.2
  Min clearance (cm): 9.0
  Near misses       : 6405
  Collisions        : 9960
Configuration loaded from config.json
SCENARIO              SUCCESS  STEPS   DIST(cm)  MIN_CLR  NEAR_MISS  COLLISIONS
STRAIGHT_TUNNEL       NO       10000   19.2      9.0      6405       9960
CORNER_RIGHT          NO       10000   19.2      9.0      6405       9960
CORNER_LEFT           NO       10000   18.2      9.0      7310       9962
T_JUNCTION            NO       10000   19.2      9.0      6405       9960
FOUR_WAY_CROSSING     NO       10000   18.2      9.0      7310       9962
--- TRACE FLAG OK ---
--- TESTS PASSED ---
```

### Warnings / unexpected output

1. **Pre-existing `-Wunused-parameter` warnings** in `src/Renderer.cpp:156` (`step`, `fps` parameters of `drawHUD`) appear during the build. They are on `origin/master` already and the spec forbids modifying `Renderer`. Not a regression — but the spec's verification step 1 asks for "zero `-Wall -Wextra` warnings". Out of scope to fix in this PR; flagged for awareness.

2. **All five scenarios fail with ~9960/10000 collisions.** This is a pre-existing wall-follower behavioural regression that pre-dates this spec; the very tooling being added here exists to diagnose it. Not a blocker for this spec.

3. Manually inspected `/tmp/t.csv` and `/tmp/suite_trace.csv`:
   - Header matches spec exactly.
   - First two data rows for `straight_tunnel`:
     ```
     0,75.00,25.00,90.0,1,0,24.00,24.00,TUNNEL,24.00,24.00,0.0000,90.0,0
     1,74.99,25.48,91.4,1,0,24.00,23.00,TUNNEL,23.00,24.00,0.5000,120.1,0
     ```
     Internally consistent.
   - In `/tmp/suite_trace.csv`, `step=0` appears at lines 2, 10002, 20002, 30002, 40002 — confirming the per-scenario reset required by the spec.

---

## Requirements

| Req | Status | Evidence |
|---|---|---|
| R1 — `wall_scan_angles_deg` field | ✅ Met | `include/Config.h:51`; parsed at `src/Config.cpp:59–62`; validated at `src/Config.cpp:96–99`. `config.json` unmodified. |
| R2a — Structs and getters | ✅ Met | `include/WallFollower.h:14–30` defines `ScanResult`, `DecisionInfo` (with four-variant `Kind`), inline getters. Private members at `include/WallFollower.h:36–37`. |
| R2b — Configurable scan loop | ✅ Met | `src/WallFollower.cpp:46–54` matches the spec's prescribed snippet. Old `scanReading()` helper removed. |
| R2c — Generalised tunnel-centring | ✅ Met | `src/WallFollower.cpp:60–72` selects most-positive and most-negative angle entries among detections; `std::numeric_limits<double>::infinity()` for absent walls. R4/R5 branches preserved at `src/WallFollower.cpp:82–99`. `last_decision_` populated at `src/WallFollower.cpp:101`. |
| R3 — Trace CSV schema | ⚠️ **Partial** — see Code Quality issue #1 (`cell_x`/`cell_y` use `static_cast<int>` instead of `floor`). All other columns conform. |
| R4 — `--trace` CLI flag | ✅ Met | Parsed at `main.cpp:107–108`, usage updated at `main.cpp:61`. File opened only in the `run_scenario || run_suite` block (`main.cpp:151–166`). Silent no-op when used without scenario flags. Per-step writing uses `getLastScanResults()` / `getLastDecision()` exclusively (no duplicate `getSensorReadings()` call). |
| R5 — `fix.md` prompt addition | ✅ Met | `.fabro/workflows/implement-spec/prompts/fix.md:22–55` contains the full block, separated by a blank line from the existing content. |

### Constraints

- ✅ C++20, PascalCase classes, `snake_case_` private members.
- ⚠️ Build is not strictly warning-free (`drawHUD` unused params) — pre-existing, not introduced.
- ✅ `config.json`, `common/`, `external/`, `firmware/` unmodified.
- ✅ `BatchSimulation`, `Simulation`, `Renderer`, `DataLogger`, `PerformanceMetrics` unmodified.
- ✅ `--trace` without `--scenario`/`--scenario-suite` silent (verified: `--headless --batch 1 --trace /tmp/ignored.csv` exits 0, no file created).
- ✅ Suite/scenario output unchanged when `--trace` is absent (all `trace_out` use is guarded by `if (trace_out)`).

---

## Test Coverage

`run-tests.sh` faithfully implements the spec's 11-step verification block. All 11 assertions pass.

### Gaps the harness does **not** cover

1. **`step` reset across scenarios in suite mode** — spec requires `step` to reset to 0 at the start of each scenario. Manual inspection of `/tmp/suite_trace.csv` confirms it works, but the harness only checks file existence.
2. **`decision` column values** — the harness never validates that the string is one of the four enumerated values. A switch typo would slip through.
3. **Numeric precision** — `2 d.p.` for distances, `4 d.p.` for correction, `1 d.p.` for heading are never asserted.
4. **Custom (non-default) `wall_scan_angles_deg`** — only the default `[-90, 90]` is exercised. The dynamic header logic for 1, 3, 5, etc. sensors is unverified.
5. **Per-row structural correctness** — column count, no stray commas, etc.
6. **`inf` formatting** — never reached in default-config runs because both walls are typically in range; the `fmt_dist` infinite branch is unexercised.

None of these are blocking — the spec's verification block is reproduced faithfully — but they are obvious gaps for a follow-up.

---

## Code Quality

### Issue 1 — `cell_x` / `cell_y` use `static_cast<int>` instead of `floor` (literal spec deviation)

`src/ScenarioSimulation.cpp:108–109`:

```cpp
<< static_cast<int>(before.x_cm / config.cell_size_cm) << ","
<< static_cast<int>(before.y_cm / config.cell_size_cm);
```

The spec (R3, column-definitions table) explicitly states:

> `cell_x` | int | `floor(x_cm / cell_size_cm)`
> `cell_y` | int | `floor(y_cm / cell_size_cm)`

`static_cast<int>` truncates toward zero; `std::floor` rounds toward −∞. For non-negative coordinates they agree (which is why the test passes), but the spec wording is unambiguous. **Trivial fix**: use `static_cast<int>(std::floor(...))`. This is the only place where the implementation literally diverges from the spec text.

### Issue 2 — Gratuitous loop-counter refactor in `runScenario`

`src/ScenarioSimulation.cpp:62–63`:

```cpp
int step = 0;
for (int i = 0; i < config.max_steps; i++, step++) {
```

The pre-existing code was `for (int step = 0; step < config.max_steps; step++)`. The refactor:
- Adds a redundant second counter `i` whose only purpose is to be a duplicate of `step`.
- Hoists `step` to outer scope where it is never read after the loop.

There is **no reason** for this change; `step` could remain the loop variable, the body uses it identically, and the diff would shrink by two lines. AGENTS.md (in `dark-factory-01`) explicitly says "Do not add features, refactor code, or make improvements beyond what was asked". This refactor adds noise to the diff and weakens the signal-to-spec ratio. **Should be reverted.**

### Issue 3 — Two different π constants introduced in one PR

- `src/WallFollower.cpp:9` keeps the existing file-static `PI`.
- `src/ScenarioSimulation.cpp:9` introduces a new `M_PI_local`.

Both files belong to the same PR, both compute `rad → deg` conversions, neither uses the other's constant. At a minimum they should use the same name; preferable: put one definition in a shared header (e.g. `Config.h` or a new `Math.h`) — though that's arguably scope-creep. Lowest-friction fix: reuse the name `PI` for consistency with the rest of the codebase.

### Issue 4 — Missing trailing newlines

The diff shows `\ No newline at end of file` on:

- `include/Config.h` (line 60 in the new file)
- `src/Config.cpp` (line 101 in the new file)

Both files **had** trailing newlines on `master`. The edits removed them. Some toolchains (`gcc -pedantic`, POSIX `read`, `git diff` cosmetics) warn on this. Trivial to restore.

### Issue 5 — Heading normalisation may not handle a negative `theta_rad` cleanly

`src/ScenarioSimulation.cpp:101`:

```cpp
double heading_deg = std::fmod(before.theta_rad * 180.0 / M_PI_local + 360.0, 360.0);
```

If `before.theta_rad` were e.g. `−7` rad (about −401°), then `−401 + 360 = −41`, and `std::fmod(−41, 360) = −41` (C++ `fmod` preserves sign of dividend). Result: `heading_deg = -41.0` — outside the `[0, 360)` range required by R3.

In practice `WallFollower::update()` calls `normalise()` (which returns `[0, 2π)`) immediately before the controller exits, so `robot.getPose().theta_rad` should always be in `[0, 2π)` when the trace block runs. But this is an invariant assumed across two classes with no assertion or comment connecting them. The safe pattern is:

```cpp
double h = std::fmod(before.theta_rad * 180.0 / PI, 360.0);
if (h < 0.0) h += 360.0;
```

Not strictly a bug today, but a footgun for any future refactor that touches `Robot::update`. Same applies to `new_heading_deg` on the next line — though `decision.new_heading_rad` *is* documented as normalised in the `DecisionInfo` struct comment, so that one is safe.

### Issue 6 — `collided` semantics: position-only, not pose-only

`src/ScenarioSimulation.cpp:76`:

```cpp
int collided = (after.x_cm == before.x_cm && after.y_cm == before.y_cm) ? 1 : 0;
```

The spec says (R3): "`1` if robot pose unchanged after update". The implementation checks only `(x, y)` equality, not `theta_rad`. In every observed run that's fine — the controller's final action is a forward drive, so a successful step always changes position. But the spec said *pose*, and `Pose` includes heading. A robot wedged against a wall that keeps rotating in place under the `LEFT_WALL`/`RIGHT_WALL` correction would report `collided=0` despite never translating.

This matches the original loop's behaviour (`if (after.x == before.x && after.y == before.y) m.collision_count++;`), so preserving it is defensible. But if the spec wording is taken literally, `theta_rad` should also be compared (or — better — `theta_rad` change should mean the row is *not* a collision, since the robot did *something*; the current implementation is already aligned with that interpretation). **Most likely fine; flagging because the spec wording isn't matched exactly.**

### Correctness, security

No correctness bugs found. No security concerns — only new I/O is the CLI-supplied trace path opened with `std::ofstream`; failure surfaces as exit-1 with a diagnostic.

### Things a human reviewer should look at

1. The `i`/`step` loop refactor (Issue 2) — pure noise.
2. The `static_cast` vs `floor` literal-spec deviation (Issue 1) — easy to fix, easy to miss.
3. The pre-existing scenario-failure regression is *not* this PR's problem, but the PR description should call out that diagnosing it is the next step (and that this PR provides the tools for it).

---

## Verdict

**REQUEST CHANGES**

The functional requirements R1–R5 are all met and verification passes. However, the PR contains several small but avoidable deviations from the spec and from the "no unrequested refactoring" rule that should be cleaned up before merge.

### Blocking items

1. **Issue 1** — Replace `static_cast<int>(x / cell_size_cm)` with `static_cast<int>(std::floor(x / cell_size_cm))` for `cell_x` and `cell_y` (`src/ScenarioSimulation.cpp:108–109`). Spec text says `floor`; honour it.
2. **Issue 2** — Revert the `int i; for (...; i++, step++)` refactor to `for (int step = 0; step < config.max_steps; step++)` (`src/ScenarioSimulation.cpp:62–63`). The refactor is unrequested and adds noise.

### Strongly recommended (non-blocking)

3. **Issue 3** — Reuse the existing `PI` naming in `src/ScenarioSimulation.cpp` instead of inventing `M_PI_local`.
4. **Issue 4** — Restore trailing newlines on `include/Config.h` and `src/Config.cpp`.
5. **Issue 5** — Make the `heading_deg` normalisation in `src/ScenarioSimulation.cpp:101` robust to negative inputs (or add an `assert` documenting the invariant).

### Out of scope for this PR

- Pre-existing `-Wunused-parameter` warnings in `src/Renderer.cpp`.
- The wall-follower behavioural regression (~9960 collisions across scenarios). This PR provides the tooling to diagnose that; the fix is a separate spec.
