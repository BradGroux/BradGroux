# You Don't Have to Wait for Someone Else to Build It

Date: 2026-07-09

Source trigger: Eric Siu's tweet about using Fable 5 to turn company operations into a video-game-like command center: https://x.com/ericosiu/status/2074921789273129008

## Short Version

Eric Siu's post is not really about making work look like a video game.

The useful idea is smaller and more practical: he took the way he already thinks about his business, connected real systems to it, and turned business signals into visible next actions. Product signups drop, so the product area is "on fire." Revenue improves, so finance shows progress. Missing data becomes fog. The system then turns those signals into quests: fix activation, revive stalled deals, clean up failed payments, train a teammate.[^siu-linkedin]

That is the part worth sharing.

You do not need to wait for a software company, agency, or internal backlog to build the first version of the tool you wish existed. If you can describe the workflow, name the signals, and define what a good next action looks like, you can build a useful first pass now.

It might be a spreadsheet. It might be a lightweight database. It might be a static HTML dashboard. It might be a repo task handed to Codex. It might be a Fable 5 prototype. The first version does not need to be perfect. It needs to make the work visible enough that people can act on it.

Build the map. Add one signal. Turn it into one next action. Verify whether that action helped. Then repeat.

## Longer Draft

Eric Siu posted about using Fable 5 to turn his company into a kind of business command center. The version he showed has a dashboard, a daily briefing, connectors, quests, and different modes for different business models. Stripe, HubSpot, Gong, Mixpanel, GA4, Ahrefs, and Metricool become inputs. Business problems become quests. A dashboard stops being a place you check after the fact and starts becoming a place that points the team at the next constraint.[^siu-linkedin]

I like that framing, but not because every company needs video-game UI.

The better lesson is that we do not have to wait around for someone else to build the exact operational tool we have in our head.

That used to be the default. A team would find a recurring bottleneck, explain it to a vendor, wait for a roadmap, file an internal ticket, wait for developer time, compromise around a generic product, and then duct-tape the process back together in spreadsheets anyway.

That is a bad default in 2026.

Spreadsheets, lightweight databases, no-code automation tools, and simple scripts already let people build first-pass workflows without waiting for a full software project. Agentic coding tools have pushed that further. OpenAI describes Codex as a software engineering agent that can write features, answer codebase questions, fix bugs, and propose pull requests.[^openai-codex] Codex web can connect to GitHub and create pull requests from its work.[^codex-web] OpenAI's own economic research summary says that as agentic tools improve, people use them for longer, more complex, and more cross-functional work.[^openai-work]

Fable 5 is another example of the same pattern at the frontier. Anthropic describes it as a model aimed at long-running autonomous work, with examples across software engineering, knowledge work, vision, memory, and long-context tasks.[^anthropic-fable] The model is not cheap, and that matters: Anthropic's pricing page lists Fable 5 at $10 per million input tokens and $50 per million output tokens, with batch discounts available.[^anthropic-pricing] So the lesson is not "throw the most expensive model at everything." The lesson is that a capable builder can now move from idea to working proof much faster than the old vendor-roadmap cycle.

That is the mental shift.

You do not need permission from a future product roadmap to test whether your workflow can be better. You need a clear bottleneck, a little data, a rough interface, and enough judgment to know when the prototype is helping versus when it is just making the process look cooler.

## The Useful Pattern

Start with one painful loop.

Not "build a business operating system." That is how these projects turn into expensive fiction. Pick one recurring problem:

- Leads are not followed up fast enough.
- Product signups are dropping and nobody notices until the weekly meeting.
- Invoices fail and the cleanup lives in someone's inbox.
- Customer escalations do not have a clear owner.
- New employees keep asking the same onboarding questions.

Then turn that loop into a small operating model:

1. What signal tells us something changed?
2. Where does that signal live?
3. Who owns the response?
4. What should the next action be?
5. How do we know the action worked?

That is enough to build the first version.

A "quest" is just a next action with context, ownership, and proof. It does not need coins, badges, or fake motivation. In a serious business tool, the useful part is clarity:

- What happened?
- Why does it matter?
- Who should look at it?
- What should they do next?
- What evidence closes the loop?

## What I Would Build First

I would skip the big command center at first.

Build one small surface:

- A Markdown or HTML daily briefing.
- A simple dashboard with three live metrics.
- A lightweight internal form or tracker.
- A GitHub issue template that turns recurring problems into structured tasks.
- A Codex task that generates the first version of a report, tool, or automation.

Then connect one real source of truth. One.

If the problem is activation, connect product analytics. If the problem is stalled deals, connect CRM data. If the problem is failed payments, connect billing events. If the problem is support load, connect tickets.

Do not connect seven systems before proving that one signal creates a better decision.

The first useful version should be boring:

1. Read one source.
2. Detect one condition.
3. Create one recommended action.
4. Assign one owner.
5. Record whether it worked.

That is the whole loop. Once that loop works, make it nicer.

## The Caveat

"Build it yourself" does not mean "ship whatever the model gives you."

If the workflow touches customer data, employee performance, compensation, payments, security, external messages, or production systems, slow down. Put a human approval step in the path. Log the decision. Review the output. Run the test. Check the cost.

The real advantage is not that AI lets you skip judgment. It is that AI lets you get to a reviewable first version faster.

That is enough to change how people work. Not because everyone becomes a full-time software engineer, but because more people can stop waiting for the perfect tool and start shaping the tools around the work they already understand.

Start small. Build the first loop. Prove it helps. Then decide whether it deserves to become real software.

## Source Notes

- Eric Siu's public post describes the Business Command Center, connectors, quests, business-map metaphor, and the idea that dashboards show what happened while a command center shows the next quest.[^siu-linkedin]
- Anthropic's Fable 5 announcement and docs establish the model context: Fable 5 is positioned for long-running autonomous tasks, with public availability through Claude surfaces and usage-credit constraints around subscription plans.[^anthropic-fable][^anthropic-redeploy]
- Anthropic's pricing docs are the cost caveat: frontier agent work can get expensive fast, especially when long-running tasks produce a lot of output tokens.[^anthropic-pricing]
- OpenAI's Codex docs establish the coding-agent side of the same trend: agents can work on repo tasks, implement features, fix bugs, and create pull requests for review.[^openai-codex][^codex-web]

[^siu-linkedin]: Eric Siu, "I used Fable 5 to turn my company into a video game," LinkedIn, accessed 2026-07-09. https://www.linkedin.com/posts/ericosiu_i-used-fable-5-to-turn-my-company-into-a-activity-7478794763232772096-MtHx
[^anthropic-redeploy]: Anthropic, "Redeploying Claude Fable 5," 2026-06-30. https://www.anthropic.com/news/redeploying-fable-5
[^anthropic-fable]: Anthropic, "Claude Fable 5 and Claude Mythos 5," 2026-06. https://www.anthropic.com/news/claude-fable-5-mythos-5
[^anthropic-pricing]: Anthropic, "Pricing - Claude Platform Docs," accessed 2026-07-09. https://platform.claude.com/docs/en/about-claude/pricing
[^openai-codex]: OpenAI, "Introducing Codex," 2025-05. https://openai.com/index/introducing-codex/
[^codex-web]: OpenAI Developers, "Codex web setup," accessed 2026-07-09. https://developers.openai.com/codex/cloud
[^openai-work]: OpenAI, "How agents are transforming work," 2026. https://openai.com/index/how-agents-are-transforming-work/
