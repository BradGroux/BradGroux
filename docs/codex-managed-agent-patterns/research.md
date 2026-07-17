# Research Notes

Date: 2026-07-09

Topic: Public-facing article adapting Anthropic managed-agent patterns and a ClaudeDevs advisor/executor post into practical Codex workflow guidance.

## Research Summary

The public post and Anthropic notebook both point at the same operating idea: do not make one model do every kind of work. Keep high-judgment planning and synthesis separate from token-heavy reading, checking, and execution.

The Codex version of that idea does not require copying Anthropic's Managed Agents API. Codex already exposes comparable workflow surfaces:

1. Subagents for explicit parallel delegation.
2. Built-in `explorer` and `worker` agent roles, plus custom agent files when a workflow earns it.
3. `codex exec` for non-interactive pipeline runs.
4. `AGENTS.md` and skills for durable instructions.
5. Automations and worktrees for recurring or isolated background work.
6. Review workflows for independent quality checks.

The article should make the agent workflow the point, not the model brand. The practical advice is to keep the main thread responsible for context, decisions, synthesis, and verification while sending bounded read-heavy work to workers.

## Source Findings

### ClaudeDevs Advisor/Executor Post

Source: https://x.com/ClaudeDevs/status/2074606058128224365

Used for:

- The public trigger.
- The advisor/executor diagram.
- The idea that an executor can run the main loop and call a stronger advisor model only on demand.
- The cost framing that most tokens can remain billed at the executor rate.

Access note:

- The unauthenticated public page exposed the lead post and image. The image showed "Executor / Sonnet 5 / Runs every turn" calling "Advisor / Fable 5 / On-demand" through a tool call and receiving advice back.

### Anthropic Managed Agents Folder

Source: https://github.com/anthropics/claude-cookbooks/tree/main/managed_agents

Used for:

- The list of managed-agent use cases worth adapting:
  - specialist team coordination
  - unfamiliar codebase exploration
  - human-in-the-loop gates
  - failing-test iteration
  - production operation
  - issue-to-PR orchestration
  - plan-big/execute-small coordination
  - prompt versioning and rollback
  - memory
  - outcome grading
  - data analysis
  - Slack bot workflows
  - SRE incident response

Editorial decision:

- The article does not copy the API mechanics. It extracts the workflow patterns and maps them to Codex surfaces.

### Anthropic Plan Big, Execute Small Notebook

Source: https://github.com/anthropics/claude-cookbooks/blob/main/managed_agents/CMA_plan_big_execute_small.ipynb

Used for:

- Coordinator pattern: a stronger model plans and synthesizes; lower-cost workers do token-heavy reading in separate context windows.
- The claim that the notebook compares a team run to a solo frontier-agent control with matched verification rigor.
- The caveats:
  - matched rigor matters
  - delegation has overhead
  - the verification standard only covers what is explicitly checked
  - the coordinator only knows what its prompt says about workers

Editorial decision:

- The article keeps this as a principle, not a promise that every multi-agent run is cheaper or faster.

### OpenAI Codex Manual

Source: https://developers.openai.com/codex/codex-manual.md

Verification:

- Refreshed through the local OpenAI docs helper on 2026-07-09.
- Helper reported the cached manual was current.

Used for:

- Current Codex mapping and source links.

### OpenAI Codex Subagents

Sources:

- https://developers.openai.com/codex/subagents
- https://developers.openai.com/codex/concepts/subagents

Used for:

- Codex supports subagent workflows that spawn specialized agents in parallel and collect results.
- Codex only spawns subagents when explicitly asked.
- Subagents are useful for codebase exploration and highly parallel work.
- Read-heavy tasks like exploration, tests, triage, and summarization are good starting points.
- Parallel write-heavy workflows require care because agents can conflict.
- Subagent workflows consume more tokens than comparable single-agent runs.
- Built-in agents include `default`, `worker`, and `explorer`.
- Custom agents can live under `.codex/agents/` or `~/.codex/agents/`.

### OpenAI Codex Non-Interactive Mode

Source: https://developers.openai.com/codex/noninteractive

Used for:

- `codex exec` as the non-interactive CLI surface.
- Pipeline use cases: CI, scheduled jobs, release notes, summaries, structured output.
- JSON Lines output for event streams.
- Security guidance around CI and API keys.
- Autofix CI pattern that separates Codex patch generation from the PR-opening job with write permissions.

### OpenAI Codex Skills

Source: https://developers.openai.com/codex/skills

Used for:

- Skills as reusable task-specific workflow packages with instructions, resources, and optional scripts.
- Skills are available across CLI, IDE extension, and Codex app.
- Skill guidance supports the article's progression from prompt to durable workflow.

### OpenAI AGENTS.md Guidance

Source: https://developers.openai.com/codex/guides/agents-md

Used for:

- `AGENTS.md` as durable repo guidance.
- The article recommends `AGENTS.md` before custom agent frameworks because it is the simplest shared surface for build commands, test commands, conventions, review expectations, and done criteria.

### OpenAI Automations and Worktrees

Sources:

- https://developers.openai.com/codex/app/automations
- https://developers.openai.com/codex/app/worktrees

Used for:

- Automations can run recurring checks and report findings.
- Git repos can run automations in local project mode or in a worktree.
- Worktrees isolate background or parallel work from unfinished local changes.

## Public Sharing Angle

The strongest public angle is:

> The next step in useful agent work is not one giant magic agent. It is a clean main thread, bounded workers, durable context, and verification.

This keeps the article practical and avoids vendor-deck framing.

## Editorial Decisions

- Kept the article public-safe: no private repo names, local paths, internal notes, or unpublished workflow details.
- Avoided detailed model pricing because pricing changes and was not needed for the public point.
- Avoided promising cost savings. The article says matched rigor matters before comparing cost or speed.
- Kept the recommendation simple: prompt first, then `AGENTS.md`, then skills, then automations, then custom agents/plugins only when the pattern repeats.
- Kept human gates explicit for secrets, payments, production systems, external messages, and credentials.
