Key Takeaways

    Most organizations hit a ceiling at "AI writes code, a person reviews it." I did too. Breaking through that ceiling forced me to rethink quality assurance from scratch — you can't just bolt AI onto your existing review process and expect the bottleneck to vanish.


    Holdout scenarios are what make this whole thing work. Borrowed the idea from how ML models get evaluated. The coding agent never sees the acceptance tests. A separate LLM judges whether output satisfies them. That wall between the two is everything.


    AGENTS.md files and progressive-disclosure docs are the single best thing you can do for agent quality today, right now, this afternoon. Two hours of writing. Permanent payoff.


    Each phase has to stand on its own. If you only ever ship Phase 1, fine — the team should still be noticeably faster.


    This doesn't touch your deployment pipeline. At all. It replaces the person typing code and the person squinting at a diff. Everything after merge is identical to what you already have.


1. The Problem Nobody Talks About

I keep reading blog posts about AI coding assistants and the "10x developer" thing and I want to be honest: they're leaving out the uncomfortable part.


Yes, every team has adopted something — Cursor, Copilot, Cody, whatever. Yes, developers crank out code faster. I'm not disputing that. What I'm saying is that we celebrated too early. We automated the typing. The typing. Meanwhile, a developer still sits around for four hours waiting on a code review that amounts to a rubber stamp, then spends another forty-five minutes testing the thing by hand on localhost, then goes back and forth with the reviewer about whether a variable name is descriptive enough.


The bottleneck didn't disappear. It packed up and moved down the hall.


I run a platform team. Eight engineers, roughly a dozen microservices, Java and TypeScript. By February 2026 we'd reached what I've been calling Level 2 autonomy — AI writes most of the code, AI reviews PRs automatically, we even had agents fixing Dependabot security alerts on their own. Sounds great in a slide deck. Then I actually sat down and tracked where everyone's time went for two weeks.


Activity	Time per Occurrence	Honest Assessment
Waiting for a human code review	2–8 hours	Minimal value. Rubber-stamping was rampant.
Review back-and-forth	30–90 minutes	Sometimes useful, often just style nitpicking.
Manual testing on localhost	30–60 minutes	Valuable when done well. Rarely done well.
Investigating production bugs	30 min – 2 hours	The actual fix was usually five lines of code.
Writing boilerplate	Hours per feature	Zero value. Pure waste.


That table made me angry. We'd spent all this energy adopting AI tools, and the result was... we type faster, but everything around the typing is the same slow, manual, inconsistent mess it always was.


Then two things landed in the same week that changed my thinking.


StrongDM published a writeup about what they called a "software factory" — three engineers, zero human-written code, zero human-reviewed code, holdout scenarios and digital twins handling QA [1]. Same week, OpenAI dropped their Harness Engineering paper — a million lines of code, none of it hand-written, built in a tenth of the usual time [2]. Both teams reporting 3–10x sustained velocity. Not on a hackathon demo. On real products. Over months.


I thought: okay, so it's actually possible. What would it take to get us there?

That question consumed my next several weeks.
2. What I Mean by "Dark Factory."

Quick vocab check because I've been using this term internally, and I want to make sure it translates.


In manufacturing, a dark factory is a plant that runs with the lights off. No people on the floor. Robots do everything. In our world, it means a pipeline where no human writes code, no human reviews code, and no human manually tests code. Humans write specs and acceptance criteria. That's it. The system does the rest.


I also started using an autonomy-level framework (stolen shamelessly from the self-driving car people) to talk about where we are and where we're going:
Level	What It Looks Like
1	AI finishes your sentences. You do everything else.
2	AI writes whole functions or files. You review every single change.
3	AI generates code from specs. Holdout scenarios gate quality. You approve the merge.
3.5	Same as 3, except some services auto-merge without you.
4	Full dark factory. Specs go in, tested code comes out merged, your existing pipeline deploys it.


Most teams I talk to are somewhere around Level 2. A few are flirting with Level 3. The gap between 2 and 3 is where all the hard design problems live, and it's also where I spent most of my design energy.
3. Where We Started (Because That Matters)

I want to be upfront about our starting point because it matters a lot. Going from zero to dark factory is a completely different problem than going from "team that already trusts AI tooling" to dark factory. We were the latter.


Here's what we already had running:

    PR review bot. A reusable GitHub Action wired up across every repo. AI agent triggers on every PR targeting release, posts review comments using a shared prompt template. It wasn't perfect — it'd occasionally fixate on irrelevant things — but it caught real issues often enough that people actually read its comments. That's a higher bar than it sounds.


    Security auto-fix. Dependabot pops an alert, an agent generates a fix, the fix runs through the full build and test suite, and if everything passes, a PR shows up. We had this on one service. It just... worked. Nobody talked about it anymore, which is the highest compliment you can pay to infrastructure.


    Renovate. Every six hours, across every repo. Dependency updates. Boring. Reliable. Exactly right.


    Real CI/CD. Containers, IaC, automated deployments. The deployment pipeline was never our problem.


    Decent-ish test coverage. JUnit 5, pytest, Playwright for E2E. Patchy in places, but enough of a foundation that you could build on it without starting from scratch.


And maybe the most important thing: my team had already bought in. They'd seen agents do useful work autonomously. They weren't scared of it. That cultural piece turned out to be just as load-bearing as any of the technical stuff.
4. The Design: Four Phases, Each One Worth Doing On Its Own

I don't trust any proposal that only pays off after you've built the whole thing. That's how you end up eighteen months into a project with nothing to show for it. So I carved this into four phases, each one independently valuable. If we got to Phase 1 and stopped forever, we'd still be better off.
4.1 Phase 1 — Give the Agents Better Context

The biggest bang for the buck has zero to do with autonomy. It's just giving the AI better information to work with.

Three things.


Progressive-Disclosure Docs

Every repo gets an AGENTS.md file. About a hundred lines. Think table of contents, not encyclopedia. What the service does. Major architectural patterns. Directory layout. External dependencies. Then a docs/ folder with deeper writeups on coding patterns, API conventions, auth, testing.


The idea (which I got from the OpenAI paper [2]) is progressive disclosure. Agent reads the map. Needs more detail on auth? Drills into docs/auth.md. You wouldn't dump a 500-page wiki on a new hire's first morning. Same principle.


Here's a stripped-down example:

# AGENTS.md — QueryEngine

## What This Service Does
Query execution layer for the analytics platform. Receives SQL
from the frontend, validates and transforms it, runs it against
the data warehouse, returns results.

## Architecture
- Java 21, Spring Boot 3.5, Gradle multi-module
- SQL parsing via JSQLParser
- JWT auth on all endpoints

## Key Patterns
- Controllers extend generated interfaces from the OpenAPI module
- Services use constructor injection
- See docs/coding-patterns.md for the full list

## Directory Map
- server-java/src/main/java/.../controller/ — REST endpoints
- server-java/src/main/java/.../service/    — Business logic
- server-java/src/test/                     — JUnit 5 tests


I wrote our first one on a Thursday afternoon. By Friday morning, the quality difference in agent-generated PRs for that repo was obvious. Not subtle. Obvious. And that benefit compounds — every single AI interaction with that repo benefits, forever.

Build-Before-Push

Simple rule: the agent runs build + full test suite before it pushes anything. If something breaks, it fixes it locally. No more opening a PR just to watch CI fail, pushing a fix, watching CI fail differently, repeat. Phase 1 enforces this through a rules file. Later phases make it a hard gate.

Linters That Talk to Agents

This is the other big takeaway from the OpenAI paper. If you have architectural rules — "services don't import from controllers," "all REST endpoints need auth annotations" — encode them as linter checks, not wiki pages.


But here's the trick that actually makes the difference: write the error messages as instructions, not descriptions.


Bad: "Service layer depends on controller layer."

Good: "Service class imports from controller package. Services must not depend on controllers. Move the shared type to the model package."


With the first message, the agent flails around guessing. With the second, it fixes the problem correctly on the first try almost every time. I've watched this play out on dozens of PRs at this point. The delta is dramatic.

    What Phase 1 gets you by itself: Better PRs, faster reviews, fewer broken builds, and the security auto-fix workflow running on every service instead of just one. Nobody's workflow changes. Everything just gets a little better.

4.2 Phase 2 — Spec-Driven Development with Holdout Scenarios

This is the real thing. The core of the whole design. Everything else is scaffolding for this.

Goal: engineer writes a spec. System produces working, validated, merge-ready code.


The Spec Format

A spec is a markdown file with YAML frontmatter. Two flavors.


Feature specs say what to build — goal, requirements, constraints.


Bug specs describe the symptom and nothing else. That distinction matters more than it looks like it should. The bug spec doesn't say "I think the null check is missing on line 47." It says "this endpoint returns 500 when supplier is null, it should return 400 with a validation error." The agent goes and figures out why on its own.


Feature spec:

---
target_repo: ExampleOrg/QueryEngine
target_branch: release
type: feature
---
# Add SQL Validation Endpoint

## Goal
POST /api/v1/sql/validate — validates SQL without executing it.

## Requirements
- Validate syntax, reject non-SELECT statements, detect injection
- Extract table and column references, compute complexity score
- Return structured JSON with all the above

## Constraints
- Follow existing controller patterns
- Full test coverage
- No new dependencies

Bug spec:

---
target_repo: ExampleOrg/WritebackService
target_branch: release
type: bug-fix
---
# Writeback returns 500 when supplier is null

## Symptom
POST to /oracle/writeback with null supplier field → HTTP 500

## Expected
HTTP 400 with validation error mentioning "supplier"

## Do not assume the root cause. Investigate the codebase.


Holdout Scenarios: The Part Everyone Skips Past


Alright, this is the piece. If there's one section of this article that matters, it's this one.

Holdout scenarios are acceptance tests written in plain-English BDD format. They live in a directory the coding agent has no access to. The agent builds its implementation using only the spec. Then a completely separate system — an LLM-powered evaluator — takes those holdout scenarios and runs them against whatever the agent produced.


Three steps. The evaluator reads a scenario, uses an LLM to plan API calls that would test the described behavior. It executes those calls against an ephemeral deployment. Then it asks an LLM: did the responses actually satisfy the scenario?


Example:

---
service: queryengine
feature: sql-validation
priority: P0
---
# SQL Injection Detection

## Scenario
POST to /api/v1/sql/validate with:
sql: "SELECT * FROM users; DROP TABLE users; --"

Then valid should be false.
Errors should mention disallowed statement types.


Each scenario runs three times — two out of three must pass (smooths out the LLM non-determinism in the judging step). Overall gate: 90% of scenarios must pass before the PR can move forward.


Here's the part I want to hammer home: the coding agent never sees these scenarios. Ever. If the agent fails and gets a retry, it gets a one-line failure message — "SQL Injection Detection failed: endpoint returned 500" — not the scenario text. It can't game the test.


This is exactly the same idea as train/test separation in ML. You don't let the model see the evaluation data. If you do, it overfits. The holdout scenarios are the test set. The spec is the training data. The wall between them is what makes the quality gate meaningful.

Why This Kills BDD's Biggest Problem

I've been on three different teams that adopted Cucumber. Every single one eventually drowned in step-definition maintenance. The glue code rots. Somebody changes an API response format and forty step definitions explode. It's a nightmare.


LLM-evaluated scenarios don't have step definitions at all. The LLM figures out how to exercise each scenario dynamically, every time. API changes shape? Evaluator adapts. You maintain the scenario text — plain English — and nothing else. I genuinely think this is a better testing paradigm than anything we had before, even setting aside the autonomous code generation angle.

The Orchestrator

A Python script, triggered by GitHub Action. Engineer pushes a spec file. Action clones the target repo, hands the spec to the coding agent, waits for code, runs build and tests, opens a PR. If the agent fails, the orchestrator appends the failure to the prompt and tries again on the same branch. The agent is behind an abstraction — swapping vendors is literally one line in a config file. Don't marry any single AI provider. You'll regret it.

Ephemeral Environments

Scenario evaluation needs somewhere to run the code. We deploy each PR as a container revision on our existing dev/staging infra. The revision inherits everything — network config, identity, env vars, secrets. No new infrastructure to set up. Five-stage pipeline: build image, deploy ephemeral revision, run evaluator, decide outcome, tear it down.

Humans Still Approve in Phase 2

I want to be clear about this: Phase 2 is not auto-merge. The system generates code, validates it against scenarios, and produces a satisfaction report. A human looks at the report, maybe glances at the diff, and clicks merge.

But notice what changed. The human isn't reading code line by line anymore. They're reviewing results. "Did the scenarios pass? What's the satisfaction rate?" That's a five-minute task, not a two-hour task. Totally different cognitive load.

    What Phase 2 gets you: Specs produce validated code in hours, not days. Bug fixes go from symptom description to merged PR with no human coding. That localhost testing ritual — the most inconsistent, time-consuming step in the old flow — is gone entirely.

4.3 Phase 3 — Start Removing the Human Gate

After enough Phase 2 PRs go through with the human rubber-stamping every time — and I bet this happens faster than you'd guess — you start taking the training wheels off.


Not everywhere at once. You pick one or two services where scenario coverage is solid. Three things have to be true:
What We Measure	What It Has to Be
Scenario pass rate over last 20 PRs	Above 90%
False positive rate (scenarios said yes, code was actually broken)	Below 5%
Human override rate (human rejected something the scenarios passed)	Below 10%


The actual configuration change is one line — swap "label for review" to "merge." Any team member can still block a PR before the merge window closes.


This phase also adds quality maintenance agents. Weekly background jobs that scan for code drift, stale docs, outdated patterns. They open small cleanup PRs that go through the same scenario gate as everything else. Think of it as garbage collection for the codebase. Without this, AI-generated code accumulates these weird little inconsistencies over time — nothing catastrophic, just a slow drift toward messiness. The maintenance agents keep things tight.
4.4 Phase 4 — The Full Dark Factory

By Phase 4, most of the hard work is done. This is configuration, not architecture. Expand auto-merge to every service with strong scenario numbers. Wire up the issue tracker so tickets tagged bot:fix auto-generate specs and flow through the pipeline. Build dashboards.


The one genuinely new piece of infrastructure: digital twins — mock servers for external dependencies that cause flakiness or cost during scenario evaluation. Build them only as you need them, starting with whatever external service is giving you the most grief.


End state: engineers write specs and scenarios. They think about what the product should do and how to verify it does that. The system does everything else. Deploys go through the same pipeline as always. Nothing downstream of merge changes at all.
5. The Architecture, Briefly

Four layers. The boundaries matter more than the guts of any individual layer.
Layer	Who Owns It	What's In It
Inputs	Humans	Specs, holdout scenarios, AGENTS.md files, linter rules
Code Generation	Autonomous	Agent reads spec + repo knowledge, generates code, builds, tests, self-reviews, opens PR
Validation	Autonomous, isolated	Standard CI first (build, unit tests, static analysis), then scenario evaluator against ephemeral deployment
Merge & Deploy	Autonomous + your existing infra	Auto-merge to main, then your existing CI/CD pipeline does what it's always done


The one thing I can't stress enough: the code generation layer and the validation layer must be completely isolated from each other. The agent can't see the scenarios. The evaluator doesn't know or care how the code was produced. That wall is the whole game. Same principle as train/test separation in ML. Without it, you don't have a quality gate. You have theater.
6. What Could Go Wrong

I don't trust proposals that skip this section.


The evaluator approves bad code. Yeah. This is the big one. LLMs judging API responses against natural-language expectations is probabilistic by nature. Our mitigations: triple-run each scenario with 2/3 pass threshold, 90% overall gate, human audit of the first fifty auto-merged PRs, and the entire existing CI/CD pipeline still runs after merge. If something truly broken gets through all of that, I'd be impressed and terrified.


People don't want to stop writing code. Real risk. Developers have identity wrapped up in code authorship. "Your job is now writing specs" lands differently than you'd hope. The phased approach helps — Phase 1 doesn't ask anyone to change anything. By Phase 2 they've seen the results. But I won't pretend this is easy. You need to actively manage it.


The coding agent just isn't good enough yet. Maybe. But it's abstracted behind the orchestrator. Swap it for a different one in sixty seconds. Don't get attached.


Costs blow up from retries. Hard cap at three attempts per spec. Token monitoring with alerts. StrongDM reported roughly a thousand dollars per day per engineer-equivalent [1]. That's still way cheaper than a salary.


Scenarios go stale. Less of a problem than you'd think. No glue code to rot — the scenarios are just English text. API changes? The evaluator adapts dynamically. And the maintenance agents sweep for drift weekly.
7. Why This Matters Beyond My Team

The pattern — specs as input, isolated holdout evaluation, phased rollout of autonomous merge — isn't about Java microservices or GitHub Actions or any specific tool. It works anywhere you have services, a CI/CD pipeline, and tests. The details will look different. The architecture doesn't change.


What I keep coming back to is how much this reshapes the job itself. Writing code used to be the floor of what it meant to be an engineer. In this model, you're not on the floor anymore. You're deciding what to build and how to know it's right. That's the ceiling. It's closer to product engineering than to what most of us were trained to do. Whether that excites you or terrifies you probably says something about which parts of this job you find most rewarding.


For eight people, the math is compelling. A working dark factory should give us the sustained output of twenty-five or thirty engineers. Not because we work more hours — because the bottleneck is just... gone.