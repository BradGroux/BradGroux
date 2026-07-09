# Research Notes

Date: 2026-07-09

Topic: Eric Siu's Fable 5 "Business Command Center" post and the broader point that builders no longer need to wait for someone else to create the first version of a useful workflow tool.

## Research Summary

The original X URL did not expose a clean full post body through unauthenticated page access. Search snippets confirmed the topic, but the richer accessible public version was Eric Siu's LinkedIn cross-post with post text and transcript.

The post describes a Business Command Center with a dashboard, daily briefing, connectors, quests, and business-model-specific modes. The main operational idea is that company data becomes a map: problems become visible, missing data becomes fog, and business issues become assigned quests.

The article uses that as the trigger, then grounds the broader claim in three source-backed trends:

1. Low-code platforms let business users build useful internal apps without traditional software development.
2. Coding agents can turn described tasks into repo changes and pull requests.
3. Frontier models can handle longer-running autonomous work, but cost and governance matter.

## Source Findings

### Eric Siu Post

Source: https://www.linkedin.com/posts/ericosiu_i-used-fable-5-to-turn-my-company-into-a-activity-7478794763232772096-MtHx

Used for:

- Business Command Center framing.
- Dashboard, daily briefing, connector, and quest vocabulary.
- Examples: Stripe, HubSpot, Gong, Mixpanel, GA4, Ahrefs, Metricool.
- The operating distinction between dashboards that show what happened and command centers that show what to fix next.

Notes:

- This was treated as the best accessible public source for the tweet's content.
- The article paraphrases the post instead of quoting it at length.

### Anthropic: Redeploying Claude Fable 5

Source: https://www.anthropic.com/news/redeploying-fable-5

Used for:

- Fable 5 availability context in July 2026.
- Public Claude surfaces where Fable 5 was restored.
- Subscription-limit and usage-credit context.

Key takeaway:

- Fable 5 access was capacity-managed and tied to usage limits/credits, which supports the cost/governance caveat in the article.

### Anthropic: Claude Fable 5 and Claude Mythos 5

Source: https://www.anthropic.com/news/claude-fable-5-mythos-5

Used for:

- Anthropic's positioning of Fable 5 as useful for longer autonomous work.
- Examples across software engineering, knowledge work, vision, memory, and long-context tasks.
- Safety and safeguard context.

Key takeaway:

- Fable 5 is relevant to the article because it shows what a frontier model can do in long-running workflows, but Anthropic's own launch framing includes safety and access constraints.

### Anthropic: Claude Platform Pricing

Source: https://platform.claude.com/docs/en/about-claude/pricing

Used for:

- Current pricing cited in the article: Fable 5 at $10 per million input tokens and $50 per million output tokens.
- Batch discount context.

Key takeaway:

- The article should not imply frontier-agent experimentation is free or costless. For long-running work, token cost is part of the operating model.

### OpenAI: Introducing Codex

Source: https://openai.com/index/introducing-codex/

Used for:

- OpenAI's description of Codex as a cloud-based software engineering agent.
- Examples: writing features, answering codebase questions, fixing bugs, and proposing pull requests.

Key takeaway:

- Codex supports the article's claim that builders can move from described workflow to working software faster than the old vendor-roadmap or internal-backlog cycle.

### OpenAI Developers: Codex Web Setup

Source: https://developers.openai.com/codex/cloud

Used for:

- Codex web can connect to GitHub repositories and create pull requests from its work.

Key takeaway:

- The practical output of an agentic coding workflow can be a reviewable pull request, not just a chat response.

### OpenAI: How Agents Are Transforming Work

Source: https://openai.com/index/how-agents-are-transforming-work/

Used for:

- OpenAI's economic research summary that frontier users use agentic tools for longer, more complex, and more cross-functional work as tools improve.

Key takeaway:

- The article's broader claim is not just about one model or one demo. It fits a broader shift toward delegated, cross-functional work.

### Microsoft Learn: What Is Power Apps?

Source: https://learn.microsoft.com/en-us/power-apps/powerapps-overview

Used for:

- Low-code baseline.
- Microsoft describes Power Apps as enabling users to create custom business apps without writing code.

Key takeaway:

- "You do not need to wait for someone else to build it" is not only an AI-coding-agent point. Low-code tools have already been moving business users in this direction.

## Editorial Decisions

- Kept the article grounded in one practical loop instead of expanding into a full business operating system.
- Treated "quests" as next actions with context, ownership, and proof, not as gamification for its own sake.
- Included a caveat for sensitive workflows: customer data, employee performance, compensation, payments, security, external messages, and production systems need approval and review.
- Avoided current promotional claims about Fable 5 subscription windows beyond what the linked sources support, because availability details can change quickly.

## Public Sharing Angle

The strongest public angle is:

> You do not need to wait for a vendor, agency, or internal backlog to build the first useful version. Start with one painful loop, one source, one signal, one owner, and one measurable next action.

That keeps the post practical and avoids turning it into generic AI hype.
