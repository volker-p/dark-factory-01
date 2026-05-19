All grep targets (`Traversal success`, `Collisions`, `SCENARIO`, `SUCCESS`, `COLLISIONS`, `STRAIGHT_TUNNEL`, `Batch complete`) are confirmed to be produced by the existing print functions that will not be changed. The batch test will catch `"Batch complete"` from `BatchSimulation.cpp:69`.

Here's a summary of everything produced:

---

## What was created

### `plan.md`

A complete implementation plan covering:

- **Goal**: one-sentence summary
- **Files to change**: 11-row table with paths and rationale
- **Implementation checklist**: 11 numbered steps with specific code snippets a junior developer can follow directly
- **Test strategy**: how the 5 verification steps are exercised, plus which existing behaviours are protected
- **Risks and edge cases**: 8 identified risks with mitigations

### `run-tests.sh`

A build-and-test script that:

1. **Installs sandbox dependencies** — cmake, build-essential, libsdl2-dev
2. **Initialises submodules** — nlohmann/json via git submodule
3. **Builds** — `cmake -B build -S .` then `cmake --build build` (no piping), prints `--- BUILD SUCCEEDED ---`
4. **Verification 1** — `--scenario straight_tunnel`: asserts `Traversal success` and `Collisions` present on stdout; asserts WallFollower state noise is absent from stdout (debug off by default)
5. **Verification 2** — `--scenario-suite`: asserts tabular column headers `SCENARIO`, `SUCCESS`, `COLLISIONS`, and `STRAIGHT_TUNNEL` row appear on stdout
6. **Verification 3** — `--debug --scenario straight_tunnel`: redirects stderr to file, asserts `wall` appears (WallFollower trace), asserts normal stdout output still present
7. **Verification 4** — `--headless --batch 5`: asserts `Batch complete` or `successful` appears in output
8. Prints `--- TESTS PASSED ---` only when all assertions pass