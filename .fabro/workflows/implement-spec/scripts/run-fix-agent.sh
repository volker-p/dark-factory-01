#!/bin/bash
set -euo pipefail
claude -p \
    --model claude-sonnet-4-6 \
    --settings '{"permissions":{"allow":["Bash(*)","Read(*)","Write(*)","Edit(*)","Glob(*)","Grep(*)","LS(*)"]}}' \
    --add-dir . \
    < .fabro/workflows/implement-spec/prompts/fix.md
