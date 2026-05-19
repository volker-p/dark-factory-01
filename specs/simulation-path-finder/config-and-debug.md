---
target_repo: volker-p/SimulationPathFinder
target_branch: master
type: bugfix
---

# Physical Configuration Consolidation & Debug Control

## Goal

Eliminate hard-coded physical constants from the codebase by making `config.json`
the single source of truth for all physical parameters, add a `--debug` CLI flag
to control debug output globally, apply straightforward improvements to
`WallFollower`, and resolve the incomplete `Maze` interface.

---

## Background

A review of the scenario-testing PR revealed three blocking issues:

1. `ScenarioSimulation` hard-codes `cell_size_cm = 20` while `config.json` sets
   `robot_radius_cm = 15`. A 15 cm robot cannot navigate a 20 cm corridor — the
   root cause is that physical parameters are scattered rather than centralised.

2. `WallFollower::debug_` is initialised to `true`, flooding stdout during every
   run. There is no way to suppress it at invocation time.

3. `Maze::hasWall` and `Maze::isWallBetween` are declared in `Maze.h` but never
   implemented, leaving the interface incomplete.

---

## Requirements

### R1 — Unified physical configuration

`config.json` is the single source of truth for all physical parameters.

Set (or update) the following fields in `config.json`:

```json
"cell_size_cm": 50,
"robot_radius_cm": 10,
"minimum_distance_to_wall": 10
```

Add `minimum_distance_to_wall` to `Config.h` / the config loader if not already
present. All components that currently use this concept (WallFollower, collision
detection, Simulation) must read it from the loaded `Config` object.

`ScenarioSimulation::runScenario` must read `cell_size_cm` from `Config` and pass
it to `Maze::createScenario` — no hard-coded literal. Same applies to any other
location in `main.cpp`, `Simulation.cpp`, or `BatchSimulation.cpp` that embeds a
physical constant directly in code.

### R2 — `--debug` CLI flag

Add a `--debug` flag to `main.cpp`. Default: debug output **off**.

When `--debug` is passed, all internal debug output (WallFollower, Simulation, or
any other component with a debug mode) is enabled.

Thread the flag through to each component that has debug output — via `Config` or
as a direct parameter, whichever matches the existing code style.

### R3 — WallFollower improvements

Apply the following straightforward improvements to `WallFollower`. Do not
restructure the algorithm; further algorithmic work is out of scope for this spec.

1. Change the default initialisation of `debug_` from `true` to `false`.
2. Add a public method `void setDebug(bool d) { debug_ = d; }` (required by R2).
3. Route all debug/trace output from `std::cout` to `std::cerr` so it does not
   pollute normal stdout and can be suppressed by the caller independently.
4. Fix any obviously wasteful patterns visible in the implementation (unnecessary
   copies, redundant condition checks, etc.) without changing observable behaviour.

### R4 — Complete or clean `Maze` interface

`Maze::hasWall` and `Maze::isWallBetween` are declared in `Maze.h` but have no
implementation.

- If these methods are called by existing code or are a natural fit for
  `ScenarioSimulation` (e.g. useful for metric calculations): implement them in
  `Maze.cpp`.
- If no caller exists and the methods add no value: remove the declarations from
  `Maze.h`.

Choose whichever option leaves the interface clean and the build free of
link errors.

---

## Files to change (expected)

| File | Change |
|---|---|
| `config.json` | Set cell_size_cm=50, robot_radius_cm=10, minimum_distance_to_wall=10 |
| `include/Config.h` | Add `minimum_distance_to_wall` field; confirm all physical fields present |
| `src/ScenarioSimulation.cpp` | Remove hard-coded cell_size_cm; read from Config |
| `include/WallFollower.h` | Default debug_=false; add setDebug(); any header-inline fixes |
| `src/WallFollower.cpp` | Route debug to stderr; obvious optimizations |
| `src/Simulation.cpp` | Pass debug flag to WallFollower |
| `main.cpp` | Add --debug flag; wire to components |
| `src/Maze.cpp` | Implement or remove hasWall/isWallBetween |
| `include/Maze.h` | Remove declarations if methods are removed |

---

## Constraints

- Build must produce zero `-Wall` warnings.
- Do not change the `BatchResults` struct or `saveSummary()` signature.
- Do not modify the core maze-generation algorithm.
- Existing `--headless --batch N` and `--scenario*` behaviours must continue to work.

---

## Verification

```bash
# 1. Clean build
cmake -B build && cmake --build build -- -Wall

# 2. Scenario run — no debug flood, clean tabular output
./SimulationPathFinder --scenario straight_tunnel

# 3. Full scenario suite — low collision counts (robot fits corridors)
./SimulationPathFinder --scenario-suite

# 4. Debug flag enables WallFollower trace on stderr
./SimulationPathFinder --debug --scenario straight_tunnel 2>/tmp/dbg.txt
grep -q "wall" /tmp/dbg.txt

# 5. Existing batch mode unbroken
./SimulationPathFinder --headless --batch 5
```
