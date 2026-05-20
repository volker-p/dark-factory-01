# Plan: ACP-Mode Agents — claude.ai Login Instead of API Key

## Context

Fabro's server (`fabro.uawg.xyz`) currently calls the Anthropic API directly using `ANTHROPIC_API_KEY` stored in `~/git-repos/UAWG-Server/fabro/.env`. Every agent node in `implement-spec` (plan, implement, fix, review) is billed against that API key.

The goal is to replace those API-key-authenticated agent invocations with `claude -p` (Claude Code CLI in print/non-interactive mode), which authenticates via the user's **claude.ai OAuth session** and draws against subscription rate limits instead of API usage.

This also removes the need for Fabro to hold an LLM credential at all.

---

## Architecture

**Current:**
```
Fabro server → Anthropic API (ANTHROPIC_API_KEY) → Claude model
```

**Target:**
```
Fabro server → command node → claude -p (host, OAuth) → Claude model
```

Agent nodes (type: LLM prompt) → Command nodes (type: shell script calling `claude -p`)

---

## Changes

### 1. `~/git-repos/UAWG-Server/fabro/.env`
Comment out / remove `ANTHROPIC_API_KEY`:
```diff
-ANTHROPIC_API_KEY=sk-ant-...
+# ANTHROPIC_API_KEY=  # replaced by ACP-mode agents (claude -p)
```

### 2. `.fabro/workflows/implement-spec/workflow.toml`
Change sandbox from Docker to local so commands execute on the host where `claude` is already authenticated:
```diff
 [run.sandbox]
-provider = "docker"
+provider = "local"
```

### 3. `.fabro/workflows/implement-spec/workflow.fabro`
Replace the four `agent` nodes with `command` nodes. Remove `model_stylesheet` from graph attributes. Add `shape=parallelogram` and `script=` to each converted node. Keep `timeout` and `max_visits`.

**Remove model_stylesheet from graph attributes:**
```diff
 graph [
     goal="Implement the spec at {{ inputs.spec_path }} in the target repository and open a pull request"
     rankdir=LR
-    model_stylesheet="
-        *         { model: claude-sonnet-4-6; reasoning_effort: medium; }
-        .planner  { model: claude-sonnet-4-6; reasoning_effort: high; }
-        .coder    { model: claude-sonnet-4-6; reasoning_effort: high; }
-        .reviewer { model: claude-opus-4-7;   reasoning_effort: high; }
-    "
 ]
```

**plan node:**
```diff
-plan [
-    label="Plan"
-    prompt="@prompts/plan.md"
-    class="planner"
-    timeout="300s"
-]
+plan [
+    label="Plan"
+    shape=parallelogram
+    script="bash .fabro/workflows/implement-spec/scripts/run-plan-agent.sh"
+    timeout="300s"
+]
```

**implement node:**
```diff
-implement [
-    label="Implement"
-    prompt="@prompts/implement.md"
-    class="coder"
-    thread_id="impl"
-    fidelity="full"
-    timeout="900s"
-    max_visits=4
-]
+implement [
+    label="Implement"
+    shape=parallelogram
+    script="bash .fabro/workflows/implement-spec/scripts/run-implement-agent.sh"
+    timeout="900s"
+    max_visits=4
+]
```

**fix node:**
```diff
-fix [
-    label="Fix"
-    prompt="@prompts/fix.md"
-    class="coder"
-    thread_id="impl"
-    fidelity="full"
-    timeout="600s"
-    max_visits=3
-]
+fix [
+    label="Fix"
+    shape=parallelogram
+    script="bash .fabro/workflows/implement-spec/scripts/run-fix-agent.sh"
+    timeout="600s"
+    max_visits=3
+]
```

**review node:**
```diff
-review [
-    label="Review"
-    prompt="@prompts/review.md"
-    class="reviewer"
-    timeout="300s"
-]
+review [
+    label="Review"
+    shape=parallelogram
+    script="bash .fabro/workflows/implement-spec/scripts/run-review-agent.sh"
+    timeout="300s"
+]
```

### 4. New: `.fabro/workflows/implement-spec/scripts/run-plan-agent.sh`
```bash
#!/bin/bash
set -euo pipefail
SPEC="{{ inputs.spec_path }}"   # Fabro substitutes this before execution
PROMPT_FILE=$(mktemp)
sed "s|{{ inputs.spec_path }}|${SPEC}|g" \
    .fabro/workflows/implement-spec/prompts/plan.md > "$PROMPT_FILE"
claude -p \
    --model claude-sonnet-4-6 \
    --dangerously-skip-permissions \
    --add-dir . \
    < "$PROMPT_FILE"
rm -f "$PROMPT_FILE"
```

### 5. New: `.fabro/workflows/implement-spec/scripts/run-implement-agent.sh`
```bash
#!/bin/bash
set -euo pipefail
SPEC="{{ inputs.spec_path }}"
PROMPT_FILE=$(mktemp)
sed "s|{{ inputs.spec_path }}|${SPEC}|g" \
    .fabro/workflows/implement-spec/prompts/implement.md > "$PROMPT_FILE"
claude -p \
    --model claude-sonnet-4-6 \
    --dangerously-skip-permissions \
    --add-dir . \
    < "$PROMPT_FILE"
rm -f "$PROMPT_FILE"
```

### 6. New: `.fabro/workflows/implement-spec/scripts/run-fix-agent.sh`
Fix agent has no template variables in its prompt; it reads `test-output.txt` (already in the working dir).
```bash
#!/bin/bash
set -euo pipefail
claude -p \
    --model claude-sonnet-4-6 \
    --dangerously-skip-permissions \
    --add-dir . \
    < .fabro/workflows/implement-spec/prompts/fix.md
```

### 7. New: `.fabro/workflows/implement-spec/scripts/run-review-agent.sh`
```bash
#!/bin/bash
set -euo pipefail
SPEC="{{ inputs.spec_path }}"
PROMPT_FILE=$(mktemp)
sed "s|{{ inputs.spec_path }}|${SPEC}|g" \
    .fabro/workflows/implement-spec/prompts/review.md > "$PROMPT_FILE"
claude -p \
    --model claude-opus-4-7 \
    --dangerously-skip-permissions \
    --add-dir . \
    < "$PROMPT_FILE"
rm -f "$PROMPT_FILE"
```

---

## Prerequisites

- `claude` CLI must be installed on the Fabro host (`which claude`)
- `claude` must be authenticated: run `claude auth login` once on the host (stores OAuth session)
- Verify model availability for the subscription: `claude -p --model claude-opus-4-7 "hello"` — downgrade to `claude-sonnet-4-6` for the review agent if opus is not available on the plan

---

## Trade-offs

| Feature | Before | After |
|---|---|---|
| Auth | `ANTHROPIC_API_KEY` in Fabro .env | claude.ai OAuth session on host |
| Billing | API pay-per-token | Subscription rate limits |
| Sandbox | Docker (isolated) | Local (host execution) |
| Conversation threading | `thread_id="impl"` (implement+fix share history) | File-based only (`test-output.txt`, `plan.md`) |
| Model control | `model_stylesheet` in workflow.fabro | `--model` flag per script |

The `thread_id` loss is acceptable: `fix.md` already instructs the agent to read `test-output.txt` and trace through the code — file context is the primary mechanism anyway.

---

## Critical Files

| File | Change |
|---|---|
| `~/git-repos/UAWG-Server/fabro/.env` | Remove/comment `ANTHROPIC_API_KEY` |
| `.fabro/workflows/implement-spec/workflow.toml` | `provider = "local"` |
| `.fabro/workflows/implement-spec/workflow.fabro` | 4 agent nodes → command nodes |
| `.fabro/workflows/implement-spec/scripts/run-plan-agent.sh` | New |
| `.fabro/workflows/implement-spec/scripts/run-implement-agent.sh` | New |
| `.fabro/workflows/implement-spec/scripts/run-fix-agent.sh` | New |
| `.fabro/workflows/implement-spec/scripts/run-review-agent.sh` | New |

Prompt files (`.fabro/workflows/implement-spec/prompts/*.md`) are **unchanged**.

---

## Verification

1. Smoke test without API key: `fabro run hello` — should succeed
2. Run against a simple spec:
   ```
   fabro run implement-spec --input spec_path=specs/simulation-path-finder/wall-follower-update.md
   ```
3. Confirm `plan.md` and `run-tests.sh` appear in the working directory after the plan node
4. Confirm `target-repo/` has a new commit after the implement node
5. Watch live: `fabro attach <run-id>`
6. If auth errors occur on any node, re-run `claude auth login` on the host


## Enable claude on the fabro server container

claude is not on the Fabro host or in the container, and the container has no Node/npm. The container needs a custom image with claude installed. Here's the plan:

1. Create ~/git-repos/UAWG-Server/fabro/Dockerfile on the host:

FROM ghcr.io/fabro-sh/fabro:nightly                                                                                                                                                                                      
RUN apk add --no-cache nodejs npm && \                                                                                                                                                                                   
npm install -g @anthropic-ai/claude-code

2. Update docker-compose.yml — swap image: for build: on the fabro service and add a named volume for claude's auth credentials so they survive container restarts:

   fabro:
-    image: ghcr.io/fabro-sh/fabro:${FABRO_VERSION:-nightly}
+    build: .                                                                                                                                                                                                            
     container_name: fabro                                                                                                                                                                                               
     volumes:
   - fabro-storage:/storage
   - /var/run/docker.sock:/var/run/docker.sock
+      - claude-auth:/root/.claude                                                                                                                                                                                       

volumes:                                                                                                                                                                                                                
fabro-storage:
+  claude-auth:

3. Rebuild and start:

cd /opt/fabro                                                                                                                                                                                                            
docker compose build fabro                                                                                                                                                                                               
docker compose up -d fabro

4. Authenticate claude inside the container:

docker exec -it fabro sh                                                                                                                                                                                                 
claude auth login

claude auth login will print a URL — open it in your browser on any machine, authorize, paste the code back in the terminal. The token lands in /root/.claude/ which is persisted by the claude-auth volume. 