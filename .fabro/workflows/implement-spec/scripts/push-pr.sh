#!/bin/bash
set -euo pipefail

# Derive PR title from plan.md and a timestamped branch name
TITLE=$(grep '^# ' plan.md | head -1 | sed 's/^# //')
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-\+/-/g;s/^-//;s/-$//' | cut -c1-50)
BRANCH="factory/${SLUG}"

cd target-repo

git config user.email "fabro@dark-factory"
git config user.name "Fabro Dark Factory"

# Commit anything not yet committed (staged or unstaged)
git add -A
if ! git diff --cached --quiet; then
    git commit -m "$TITLE"
fi

# Push branch to origin
git push origin "HEAD:refs/heads/${BRANCH}"

# Open draft PR on target repo
gh pr create \
  --title "$TITLE" \
  --body "Automated implementation by the Fabro dark factory.

**Spec**: \`{{ inputs.spec_path }}\`" \
  --draft \
  --head "$BRANCH"
