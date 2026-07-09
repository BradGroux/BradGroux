# Use Agents Like a Team, Not a Giant Chat Window

Date: 2026-07-09

Source trigger: a public ClaudeDevs post showing an "executor" model doing the main loop and calling a stronger "advisor" model on demand, plus Anthropic's managed-agent cookbooks around planner/worker patterns and OpenAI's Codex docs around subagents, `codex exec`, skills, automations, and worktrees.

## Short Version

The useful pattern is not "spawn as many agents as possible."

The useful pattern is splitting the job by the kind of work being done.

Some work needs judgment: planning, deciding what matters, comparing tradeoffs, approving risky changes, and explaining the final answer. Some work is mostly expensive reading: scanning docs, checking logs, tracing a code path, looking at a test failure, or collecting evidence from ten sources.

Those should not always live in the same context window.

Anthropic's managed-agent cookbook calls this out directly in its coordinator pattern: a stronger coordinator plans and synthesizes while lower-cost workers do the heavy reading in parallel and report back distilled findings.[^anthropic-plan-small] A ClaudeDevs post showed a related advisor pattern: an executor runs the main loop and calls a stronger advisor only when it needs guidance.[^claudedevs-advisor]

Codex has its own version of this pattern. The main thread can stay focused on the goal, constraints, decisions, and verification while subagents handle bounded exploration, tests, triage, and summaries.[^codex-subagents] For scripted runs, `codex exec` can put Codex into a pipeline and emit machine-readable JSON events.[^codex-exec] For repeated workflows, skills, `AGENTS.md`, automations, worktrees, and cloud tasks make the pattern durable instead of relying on a long prompt every time.[^codex-skills][^codex-agents-md][^codex-automations][^codex-worktrees]

That is the part worth using.

Do the planning in one place. Send workers after bounded evidence. Bring the findings back. Verify the final answer. Then decide what deserves to become a reusable instruction, skill, automation, or repo workflow.

## The Problem With One Giant Agent

It is tempting to hand one agent a big task and let it grind.

Sometimes that works. I do it all the time for smaller jobs.

The problem shows up when the task has a lot of noisy intermediate work. Big logs. Long docs. Several code paths. Many source links. CI failures with pages of output. A codebase the agent has never seen before.

If all of that gets dragged through the same conversation where you are also trying to make decisions, the thread gets worse over time. The important constraints are still there, but they are buried under command output, half-useful notes, stale assumptions, and old attempts.

OpenAI's Codex docs describe the same practical issue as context pollution and context rot. The recommended use for subagents starts with read-heavy work like exploration, tests, triage, and summarization, while being more careful with parallel write-heavy work because agents can conflict with each other.[^codex-subagent-concepts]

That is exactly right.

The main thread should not become the junk drawer for every log line the job produced.

## The Pattern

The pattern I would use is simple:

1. The main thread defines the problem.
2. The main thread decides what needs evidence.
3. Workers each get one bounded slice.
4. Workers return summaries, links, file paths, commands, and confidence.
5. The main thread resolves conflicts.
6. The main thread makes or reviews the change.
7. The main thread runs the final verification.

That last part matters.

Subagents are not a way to avoid judgment. They are a way to keep judgment from being drowned in noise.

## Where This Works Well

### Research and Source Checking

If I need to verify ten claims, I do not want one agent carrying every raw source page in the main thread. I want one worker per source group, each returning the exact claim, the source URL, and any uncertainty.

That is the strongest version of the "plan big, execute small" idea. The main thread owns the question and final answer. Workers do the reading.

### Unfamiliar Codebases

Before changing a repo, split the first pass:

- one explorer traces the request or data flow
- one explorer finds the tests and verification commands
- one explorer checks whether the docs match the code

Then bring those findings back and decide the smallest safe change.

This catches one of the most common agent failures: trusting stale docs or making a patch in the first file that looked plausible.

### CI Failure Triage

CI logs are a perfect worker job.

Pipe the log into Codex, ask for the first real failure, and keep the output short. If the fix is obvious, let the main thread patch it and rerun the failing command. If the repo has a safe automation setup, `codex exec` can run as part of a pipeline and produce structured output for the next step.[^codex-exec]

The important constraint is that credentials should not be sprayed into the same environment as untrusted repo code. OpenAI's non-interactive docs call this out in the GitHub Actions pattern: isolate the Codex job, serialize the diff, then open a PR in a separate job with write permissions.[^codex-exec]

### Reviews

A good review is naturally parallel:

- security risks
- correctness and edge cases
- missing tests
- maintainability

You can ask separate reviewers to inspect the same branch from different angles, but the main thread should still decide which findings are real. Otherwise you just get four opinions and no owner.

### Incident Triage

Incident response is another good fit if you keep the gates clear.

Workers can read logs, inspect runbooks, compare recent deploys, or summarize monitoring output. They should not silently roll back production, merge a PR, send an external message, or rotate a credential.

The split is useful because investigation can fan out. The decision to act should still have a human gate.

## Where This Goes Wrong

The lazy answer is not "more agents."

More agents means more tokens, more coordination, and more ways for the work to drift. Codex docs explicitly say subagent workflows consume more tokens than comparable single-agent runs because every subagent does its own model and tool work.[^codex-subagents]

Do not use subagents when:

- one focused thread can finish the job
- the workers would edit the same files
- the task is mostly a human decision
- the work touches secrets, payments, production systems, external messages, or credentials
- the output needs one accountable owner and no parallel evidence gathering

Parallel write-heavy work is where this pattern gets expensive fast. If two agents both decide to "clean up" the same module, you did not get leverage. You bought yourself a merge conflict and a review problem.

Use worktrees or cloud tasks when implementation needs isolation.[^codex-worktrees] Use subagents for the parts that actually split cleanly.

## What I Would Build First

I would not start by building a custom agent framework.

Start with prompts and repo instructions.

For a codebase, add or improve `AGENTS.md` first. Codex reads those files as repo guidance, and they are the right place for build commands, test commands, conventions, review expectations, and "done means verified" rules.[^codex-agents-md]

Then write one reusable prompt for a workflow you actually repeat.

For example:

```text
Use a plan-big, execute-small Codex workflow.

Main thread:
- define the question and verification bar
- split read-heavy work into independent slices
- spawn one worker per slice
- wait for all workers
- synthesize a final answer with sources and unresolved uncertainty

Worker rules:
- handle only the assigned slice
- prefer primary sources
- return short findings, source links, file paths, commands, and confidence
- do not edit files unless explicitly assigned a disjoint write set

Done when:
- every material claim has evidence
- any code change has the smallest meaningful verification
- risky actions still require explicit approval
```

If that prompt keeps proving useful, turn it into a skill. Codex skills are meant for reusable workflows with instructions, references, and optional scripts.[^codex-skills]

If the workflow needs to run on a schedule, turn it into an automation. Codex automations can run recurring checks and report findings, and for Git repos they can run in worktrees so the work stays separate from unfinished local changes.[^codex-automations]

That is the progression:

1. Prompt.
2. `AGENTS.md`.
3. Skill.
4. Automation.
5. Custom agent or plugin only when the simpler version has earned it.

## The Cost and Trust Caveat

The Anthropic notebook measured its split honestly by comparing the team against a solo frontier agent held to the same verification standard. That is the only comparison that matters.[^anthropic-plan-small]

If the solo agent reads one source per fact and the worker team checks every fact carefully, the team did not "cost more." It did more work.

The same caveat applies to Codex.

Do not judge an agent pattern by vibes. Decide the verification standard first:

- What facts need sources?
- What code paths need tests?
- What checks need to pass?
- What actions need approval?
- What is intentionally out of scope?

Then compare speed, cost, and quality.

The point is not to make agents look busy. The point is to get to a reviewable answer or patch faster without losing the evidence that makes it trustworthy.

## Where I Land

I think this is where a lot of practical agent work is heading.

Not one giant magic agent.

Not fifty unsupervised workers.

A main thread with context and judgment. Small workers with bounded jobs. Durable repo instructions. Repeatable skills. Background checks only where they make sense. Human gates around anything risky.

That is a boring answer, which is usually a good sign.

Start with the workflow. Keep the main thread clean. Delegate the noisy parts. Verify the result.

That is how these tools become useful engineering leverage instead of just a more expensive chat transcript.

## Source Notes

- ClaudeDevs published the advisor/executor framing: an executor model runs the main loop and calls a stronger advisor model on demand.[^claudedevs-advisor]
- Anthropic's managed-agent cookbook folder includes examples for specialist teams, codebase exploration, human gates, failing-test iteration, production operation, issue-to-PR orchestration, prompt versioning, memory, outcome grading, data analysis, Slack workflows, and incident response.[^anthropic-managed-agents]
- The `CMA_plan_big_execute_small.ipynb` notebook is the closest source for the coordinator pattern. It separates planning/synthesis from token-heavy research work, runs a matched solo-agent control, and calls out caveats around matched rigor and delegation overhead.[^anthropic-plan-small]
- OpenAI's Codex docs establish the Codex side of the pattern: subagents for explicit parallel work, `codex exec` for non-interactive scripted runs, skills for reusable workflows, `AGENTS.md` for durable repo guidance, automations for recurring checks, and worktrees for isolated background work.[^codex-subagents][^codex-exec][^codex-skills][^codex-agents-md][^codex-automations][^codex-worktrees]

[^claudedevs-advisor]: ClaudeDevs, public post about using Fable 5 as an advisor, accessed 2026-07-09. https://x.com/ClaudeDevs/status/2074606058128224365
[^anthropic-managed-agents]: Anthropic, `claude-cookbooks/managed_agents`, accessed 2026-07-09. https://github.com/anthropics/claude-cookbooks/tree/main/managed_agents
[^anthropic-plan-small]: Anthropic, `CMA_plan_big_execute_small.ipynb`, accessed 2026-07-09. https://github.com/anthropics/claude-cookbooks/blob/main/managed_agents/CMA_plan_big_execute_small.ipynb
[^codex-subagents]: OpenAI Developers, "Subagents," accessed 2026-07-09. https://developers.openai.com/codex/subagents
[^codex-subagent-concepts]: OpenAI Developers, "Subagent concepts," accessed 2026-07-09. https://developers.openai.com/codex/concepts/subagents
[^codex-exec]: OpenAI Developers, "Non-interactive mode," accessed 2026-07-09. https://developers.openai.com/codex/noninteractive
[^codex-skills]: OpenAI Developers, "Agent Skills," accessed 2026-07-09. https://developers.openai.com/codex/skills
[^codex-agents-md]: OpenAI Developers, "Custom instructions with AGENTS.md," accessed 2026-07-09. https://developers.openai.com/codex/guides/agents-md
[^codex-automations]: OpenAI Developers, "Automations," accessed 2026-07-09. https://developers.openai.com/codex/app/automations
[^codex-worktrees]: OpenAI Developers, "Worktrees," accessed 2026-07-09. https://developers.openai.com/codex/app/worktrees
