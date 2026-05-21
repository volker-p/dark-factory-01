#!/bin/bash
set -euo pipefail
SPEC="{{ inputs.spec_path }}"
PROMPT_FILE=$(mktemp)
sed "s|{{ inputs.spec_path }}|${SPEC}|g" \
    .fabro/workflows/implement-spec/prompts/review.md > "$PROMPT_FILE"
claude -p \
    --model claude-opus-4-7 \
    --settings '{"permissions":{"allow":["Bash(*)","Read(*)","Write(*)","Edit(*)","Glob(*)","Grep(*)","LS(*)"]}}' \
    --add-dir . \
    < "$PROMPT_FILE"
rm -f "$PROMPT_FILE"
