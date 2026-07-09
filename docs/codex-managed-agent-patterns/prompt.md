# Prompt Output

Date: 2026-07-09

## Original Request

> investigate this thread and repo - https://x.com/ClaudeDevs/status/2074606058128224365
>
> Let's build out something similar for codex, document it well too [CMA_plan_big_execute_small.ipynb](https://github.com/anthropics/claude-cookbooks/blob/main/managed_agents/CMA_plan_big_execute_small.ipynb)

Follow-up:

> Take the best use cases from here - [https://github.com/anthropics/claude-cookbooks/tree/main/managed_agents](https://github.com/anthropics/claude-cookbooks/tree/main/managed_agents)

Public-share request:

> i'd like to create a public-facing version to [https://github.com/BradGroux/BradGroux/tree/main/docs](https://github.com/BradGroux/BradGroux/tree/main/docs)
>
> Much like the you-dont-have-to-wait-to-build-it folder.

## Working Prompt

Create a public-facing Markdown article from the internal Codex managed-agent playbook.

Audience:

- Builders, operators, engineering leads, founders, and technical practitioners using coding agents.
- People who are starting to hit the limits of one giant agent thread for research, CI triage, codebase exploration, incident review, or PR work.

Message:

- The important idea is not to copy Anthropic Managed Agents or spawn a pile of workers.
- The useful pattern is separating planning/judgment from token-heavy reading and bounded execution.
- In Codex, the main thread should own context, decisions, synthesis, and verification.
- Subagents are useful for bounded, parallel, read-heavy work.
- Worktrees, `codex exec`, skills, `AGENTS.md`, automations, and review workflows are the durable Codex surfaces.
- Human gates still matter for risky actions.

Style:

- Brad-style practitioner voice.
- Plain English before technical detail.
- Proof close to claims.
- No vendor-deck language.
- No generic "AI is changing everything" framing.
- Do not make the agent the hero. The workflow is the point.

Required outputs:

- `codex-managed-agent-patterns.md` - public article.
- `research.md` - source-backed research notes.
- `prompt.md` - this prompt/output record.

Important constraints:

- Keep private local paths, internal notes, and unpublished repo workflow details out of the public article.
- Do not overclaim that multi-agent workflows are always cheaper or faster.
- Mention matched rigor before comparing cost or speed.
- Keep security, credentials, production actions, public posting, and destructive operations behind human approval.
- Do not add active `.codex/agents`, skills, automations, or repo config for this public article.

## Result Files

- `codex-managed-agent-patterns.md` - public article.
- `research.md` - source-backed source notes and editorial decisions.
- `prompt.md` - prompt and request record.
