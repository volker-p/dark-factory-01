Both files are complete. Here's a summary of what was produced:

---

## Summary

### What was read and understood

- **Spec**: `specs/simulation-path-finder/sensor-config-and-tracing.md` — a feature spec adding configurable wall-scan angles, scan/decision state structs, and a `--trace` CSV flag to `SimulationPathFinder`.
- **Target repo**: `volker-p/SimulationPathFinder` — a C++20 CMake project with SDL2 + nlohmann/json. Single executable, built via `cmake -B cmake-build-debug -S .` + `cmake --build cmake-build-debug`.
- **Key files read**: `CLAUDE.md`, `include/Config.h`, `src/Config.cpp`, `include/WallFollower.h`, `src/WallFollower.cpp`, `include/ScenarioSimulation.h`, `src/ScenarioSimulation.cpp`, `main.cpp`, `CMakeLists.txt`, `config.json`, and the existing `fix.md` (which already has the trace block — no change needed).

### `plan.md` covers

1. **Goal** — one sentence
2. **Files to change** — 8-row table with precise descriptions
3. **Implementation checklist** — 37 numbered steps covering all 8 changes, specific enough for a junior developer to follow without ambiguity
4. **Test strategy** — lists both existing tests that must not break and 11 new assertions derived from the spec's Verification section
5. **Risks and edge cases** — 9 specific risks with mitigations (sensor index, scan ordering, 0° entry, arg parsing scope, `ofstream` lifetime, heading normalisation, `setprecision` stickiness, enum init warning, transitive include)

### `run-tests.sh` covers

- Installs `cmake build-essential libsdl2-dev` if absent (both cmake-absent and SDL2-absent cases)
- Initialises submodules (nlohmann/json)
- Builds with `-Wall -Wextra` — both `cmake` configure and build as plain statements (no pipes)
- Prints `--- BUILD SUCCEEDED ---`
- Runs all 11 verification checks from the spec with explicit `grep` assertions and error messages
- Prints `--- TESTS PASSED ---`