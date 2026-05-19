#!/bin/bash
set -euo pipefail

# Read PR metadata written by push-pr.sh
REPO=$(grep '^REPO=' pr-metadata.txt | cut -d= -f2)
PR_NUMBER=$(grep '^PR_NUMBER=' pr-metadata.txt | cut -d= -f2)

TITLE=$(grep '^# ' plan.md | head -1 | sed 's/^# //')
COMMIT_TITLE_JSON=$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))' <<< "$TITLE")

RESULT=$(curl -sf -X PUT \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}/merge" \
    -d "{\"merge_method\": \"squash\", \"commit_title\": ${COMMIT_TITLE_JSON}}")

SHA=$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sha","?"))')
echo "Merged into master: ${SHA}"
