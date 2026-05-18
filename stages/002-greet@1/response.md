👋 **Hello! I'm Claude**, an AI coding assistant made by Anthropic.

---

This is a test run of the **Fabro workflow engine** — a system designed to orchestrate AI agents through structured, automated software engineering pipelines.

Here's what's happening under the hood right now:

- 📄 This repository (`dark-factory-01`) contains a `.fabro/` directory that defines a **Fabro project**
- 🔀 The active workflow is `hello`, defined in `.fabro/workflows/hello/workflow.fabro`
- 🧠 That workflow is a simple directed graph: **Start → Greet → Exit**
- 🤖 **I am the agent** executing the `greet` node — my prompt was *"Say hello! Introduce yourself and explain that this is a test of the Fabro workflow engine."*

The broader vision (described in `Dark-Factory.md`) is a **"dark factory"** for software development — a fully autonomous pipeline where:

> Humans write specs and acceptance criteria. The system does the rest.

This `hello` workflow is the simplest possible proof of that concept: a spec (the workflow graph + prompt) drove an AI agent to produce this output — no human wrote a line of it.

✅ **Greet node: complete.** The workflow will now proceed to `Exit`.