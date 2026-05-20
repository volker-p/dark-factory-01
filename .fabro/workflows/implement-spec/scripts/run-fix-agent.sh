#!/bin/bash
set -euo pipefail
claude -p \
    --model claude-sonnet-4-6 \
    --dangerously-skip-permissions \
    --add-dir . \
    < .fabro/workflows/implement-spec/prompts/fix.md
