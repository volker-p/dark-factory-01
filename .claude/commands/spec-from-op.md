# spec-from-op

Fetch the highest-priority open work package from OpenProject, interactively refine it into a Fabro spec, commit and push, then launch the implement-spec workflow.

## Steps

### 1. Fetch the work package

Call `mcp__openproject__get_highest_priority_work_package` to get the top open work package.

Show the user:
- ID, subject, priority, status, type
- Full description

### 2. Gather context interactively

Ask the user the following questions (use `AskUserQuestion` with sensible options):

**a) Scope** — Is this a new follow-up spec or a revision of an existing one? Where should the spec file go (`specs/simulation-path-finder/<slug>.md`)? Confirm or let the user choose a slug based on the WP subject.

**b) Key decisions** — Present the WP description and ask the user: Are there architectural decisions or constraints to call out in the spec? (free text, or "none")

**c) Verification** — What are the acceptance criteria beyond what is in the ticket? (free text, or "use whatever is in the ticket")

**d) Proceed?** — Confirm before writing any files.

### 3. Write the spec

Write a spec file to `specs/simulation-path-finder/<slug>.md` following this structure:

```markdown
# <Subject from WP>

## Context

<1-2 paragraph summary of WHY this change is needed, derived from WP description + user answers>

## Requirements

### R1 — <first requirement>
<details>

### R2 — <second requirement>
<details>

(add as many as needed)

## Files to change (expected)

| File | Change |
|------|--------|
| `path/to/file` | What changes |

## Verification

1. <first check>
2. <second check>
(derived from WP + user answers)
```

Store the OP work package ID in a comment at the top of the file:
```
<!-- op_work_package_id: <id> -->
```

### 4. Commit and push

```bash
git add specs/simulation-path-finder/<slug>.md
git commit -m "Add spec: <subject>"
git push
```

### 5. Launch the workflow

```bash
~/.fabro/bin/fabro run implement-spec \
  --input spec_path=specs/simulation-path-finder/<slug>.md \
  --input op_work_package_id=<id>
```

Print the run ID so the user can track it.

### 6. Confirm

Tell the user:
- The spec file path
- The WP ID that will be closed after the PR merges
- The fabro run ID
- That they need to approve the plan gate in the Fabro web UI at fabro.uawg.xyz
