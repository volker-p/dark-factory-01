---
target_repo: https://git.schloss-glarisegg.ch/plesk-git/SimulationPathFinder.git
target_branch: master
type: feature
vcs: git
---
# Populate batch simulation statistics

## Goal
After a batch run, `BatchResults` should contain real averages for completion,
steps, distance, and total training samples — not zeros.

## Background
`BatchResults` has fields `avg_completion_percent`, `avg_steps`, `avg_distance_cm`,
and `total_samples`, but `BatchSimulation::runBatch()` never populates them.
There is a comment in `src/BatchSimulation.cpp` that says exactly this:
> "Would need to expose more metrics from Simulation to calculate averages"

`Simulation` already tracks all required data internally via `PerformanceMetrics`
and `DataLogger`, but exposes none of it after a run completes.

## Requirements
1. After each simulation run completes, `BatchSimulation` must be able to read:
   - Final completion percentage
   - Total steps taken
   - Total distance travelled (cm)
   - Total training samples logged by `DataLogger`
2. `BatchResults` must contain correct averages across all runs after `runBatch()` returns.
3. `BatchSimulation::saveSummary()` must write the populated averages to the summary file.
4. Headless batch run (`--headless --batch 5`) must exit 0 and produce a non-trivial
   summary (all averages > 0 for successful runs).

## Constraints
- Add getter methods to `Simulation` — do not make members public.
- Do not change the `BatchResults` struct fields or `saveSummary()` signature.
- Do not change the core algorithm in `common/maze_explorer.c`.
- Follow all conventions in `AGENTS.md` (PascalCase classes, `snake_case` members,
  `_` suffix for private members).
- Build must be clean with zero `-Wall` warnings.

## VCS note
This repository is on a self-hosted Gitea server — `gh` CLI does not work.
Use plain `git clone <target_repo>` to clone. Credentials may be required;
check fabro secrets for `GITEA_TOKEN` or use SSH if a key is configured.
Branch from `master`, push a feature branch, open a PR via the Gitea web UI.
