Goal: Implement the spec at specs/simulation-path-finder/batch-statistics.md in the target repository and open a pull request


You are a senior software engineer. Your job is to produce a detailed implementation plan from a spec — no code yet.

## Steps

1. Read the spec at `specs/simulation-path-finder/batch-statistics.md`. Extract:
   - `target_repo` from the YAML frontmatter
   - `type` (feature or bug-fix)
   - All requirements and constraints

2. Extract the `target_repo` field from the YAML frontmatter of the spec file.
   Clone it into `target-repo/`:
   ```bash
   gh repo clone <target_repo> target-repo 2>&1 || git clone https://github.com/<target_repo>.git target-repo
   ```

3. Read `target-repo/AGENTS.md` in full. Then read any `docs/` files it references that are relevant to this spec.

4. Write `plan.md` containing:
   - **Goal** — one sentence
   - **Files to change** — table: file path, what changes and why
   - **Implementation checklist** — numbered steps, specific enough that a junior developer could follow them
   - **Test strategy** — what tests to add, which existing tests may be affected
   - **Risks and edge cases** — anything that could go wrong

5. Write `run-tests.sh` — the exact shell script to build and run the full test suite for `target-repo/`.
   Derive the commands from the `## Build & Test` section in `target-repo/AGENTS.md`.
   The script must:
   - `cd target-repo` at the top
   - Exit non-zero on any failure (`set -euo pipefail`)
   - Capture all output to stdout/stderr
   ```bash
   chmod +x run-tests.sh
   ```

Do not write implementation code. Stop after writing `plan.md` and `run-tests.sh`.