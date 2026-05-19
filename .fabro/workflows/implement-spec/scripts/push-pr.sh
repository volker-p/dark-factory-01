#!/bin/bash
set -euo pipefail

# Derive PR title and branch slug from plan.md
TITLE=$(grep '^# ' plan.md | head -1 | sed 's/^# //')
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-\+/-/g;s/^-//;s/-$//' | cut -c1-50)
BRANCH="factory/${SLUG}-$(date +%Y%m%d%H%M)"

cd target-repo

# Extract owner/repo from the git remote
REMOTE_URL=$(git remote get-url origin)
REPO=$(echo "$REMOTE_URL" \
  | sed 's|.*github\.com[:/]\(.*\)\.git|\1|' \
  | sed 's|.*github\.com[:/]\(.*\)$|\1|')

# Configure git identity
git config user.email "fabro@dark-factory"
git config user.name "Fabro Dark Factory"

# Commit any remaining staged/unstaged changes
git add -A
if ! git diff --cached --quiet; then
    git commit -m "$TITLE"
fi

# Push branch using token-authenticated HTTPS
git push "https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.git" \
    "HEAD:refs/heads/${BRANCH}"

# Create draft PR via GitHub REST API (no gh CLI needed)
BODY="Automated implementation by the Fabro dark factory.\n\n**Spec**: \`{{ inputs.spec_path }}\`"
TITLE_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))' <<< "$TITLE")
BODY_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))' <<< "$BODY")

PR_RESPONSE=$(curl -sf -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/pulls" \
    -d "{\"title\": ${TITLE_JSON}, \"head\": \"${BRANCH}\", \"base\": \"master\", \"body\": ${BODY_JSON}, \"draft\": false}")

PR_URL=$(echo "$PR_RESPONSE"    | python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])')
PR_NUMBER=$(echo "$PR_RESPONSE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["number"])')

# Write metadata for the merge step
printf 'REPO=%s\nPR_NUMBER=%s\nBRANCH=%s\n' "$REPO" "$PR_NUMBER" "$BRANCH" > ../pr-metadata.txt

echo "PR created: ${PR_URL}"
