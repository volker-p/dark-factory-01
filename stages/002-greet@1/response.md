Hello! 👋 I'm **Claude**, an AI coding assistant made by Anthropic.

This is a test of the **Fabro workflow engine** — a self-hosted orchestration platform that powers the *dark factory* autonomous development pipeline for this project.

Here's what's happening right now:

- 🏭 **Fabro** has spun up this agent run inside a Docker sandbox on `fabro.uawg.xyz`
- 🤖 **I (Claude)** am the `agent` node executing in the `hello` workflow
- ✅ This smoke-test run verifies that the full stack is wired up correctly — LLM routing, sandbox execution, and workflow graph traversal all the way through

**The bigger picture:** Once this smoke test passes, the `implement-spec` workflow (Phase 2) can take a feature or bug spec from the `specs/` directory and autonomously produce merge-ready code — complete with a pull request — against the target service repository. No human in the loop until the PR review gate.

In short: if you're reading this message, the Fabro → Claude integration is **working** 🎉