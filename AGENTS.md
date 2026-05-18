# AGENTS.md — dark-factory-01

## What This Repo Does
This is the dark factory orchestration repo. It holds the Fabro workflows, spec templates,
and holdout scenarios that drive autonomous software development across the engineering team's
service repositories. Engineers write specs here; the factory produces merge-ready code there.

See `Dark-Factory.md` for the full design rationale and phase breakdown.

## Architecture
- Workflow engine: [Fabro](https://docs.fabro.sh) (self-hosted at fabro.uawg.xyz)
- Agent: Claude (Anthropic) via Fabro's LLM routing
- Sandboxes: Docker (server-side)
- VCS integration: GitHub App (configured on fabro.uawg.xyz)

## Directory Map
```
.fabro/
  project.toml                  — project-level defaults (PR creation, sandbox)
  workflows/
    hello/                      — smoke-test workflow
    implement-spec/             — (Phase 2) spec → code → PR pipeline
    maintenance-sweep/          — (Phase 3) weekly drift/cleanup agent
specs/                          — feature and bug specs (input to implement-spec)
scenarios/                      — holdout acceptance scenarios (never seen by coding agent)
docs/                           — deep-dive references linked from this file
```

## Workflow Conventions
- Workflows are defined in `.fabro/workflows/<name>/workflow.fabro` (Graphviz DOT format)
- Per-workflow config (sandbox, model overrides) lives in `workflow.toml` next to the graph
- Node types in use: `agent` (LLM), `command` (shell), `human` (approval gate)
- Retry edges are labelled `on-failure` with a `limit` attribute (max 3)

## Running Workflows
```bash
# Smoke test
fabro run hello

# Run a spec through the implementation pipeline
fabro run implement-spec --input spec_path=specs/my-feature.md

# Detach and monitor separately
fabro run implement-spec --input spec_path=specs/my-feature.md --detach
fabro attach <run-id>
fabro inspect <run-id>
```

All runs default to Docker sandboxes on fabro.uawg.xyz.

## Spec Format
Two spec types live in `specs/`. The coding agent reads these; it never sees `scenarios/`.

**Feature spec frontmatter:**
```yaml
---
target_repo: volker-p/<service>
target_branch: main
type: feature
---
```

**Bug spec frontmatter:**
```yaml
---
target_repo: volker-p/<service>
target_branch: main
type: bug-fix
---
```

See `docs/spec-format.md` for full field reference and examples.

## Holdout Scenarios
Acceptance scenarios live in `scenarios/` and are evaluated by a separate LLM judge — the
coding agent has no access to this directory. Each scenario runs 3 times; 2/3 must pass.
The overall gate is 90% of scenarios passing before a PR can proceed.

See `docs/scenarios.md` for authoring guidelines.

## Key Docs
- `Dark-Factory.md` — design rationale, phase breakdown, autonomy levels
- `docs/spec-format.md` — spec field reference and worked examples
- `docs/scenarios.md` — how to write and structure holdout scenarios
- `docs/workflow-patterns.md` — retry loops, fan-out/fan-in, human gates
