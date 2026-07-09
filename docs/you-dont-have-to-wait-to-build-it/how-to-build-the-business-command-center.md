# How to Build the Business Command Center

Date: 2026-07-09

Companion to: [You Don't Have to Wait for Someone Else to Build It](you-dont-have-to-wait-to-build-it.md)

Source trigger: Eric Siu's post about using Fable 5 to turn company operations into a Business Command Center: https://x.com/ericosiu/status/2074921789273129008

## What You Are Building

The useful version is not a video game. It is a business operating surface.

The system has five parts:

1. A map of the business.
2. Connectors that pull in real signals.
3. Rules that decide whether an area is healthy, on fire, or hidden by missing data.
4. A quest queue that turns signals into owned next actions.
5. A daily briefing that tells the team what changed and what to do next.

Do not start by trying to build the whole company simulator. Start with one painful loop and make that loop visible.

## The Simplest Stack That Works

Use whatever tools you already have. The point is the workflow, not the vendor.

For a nontechnical first pass:

- Data store: Google Sheets, Airtable, Notion database, Coda, or a CSV file.
- Automation: Zapier, Make, n8n, Pipedream, GitHub Actions, or a scheduled script.
- Queue: Trello, Linear, GitHub Issues, Notion, Airtable, or a spreadsheet tab.
- Dashboard: Looker Studio, Metabase, Grafana, Evidence, Observable, a static HTML page, or the built-in charting in your data tool.
- Briefing: email, Slack, Discord, work chat, or a Markdown file posted somewhere the team reads.

For a technical first pass:

- Data store: SQLite for a prototype, Postgres when more people depend on it.
- Worker: a small Node, Python, or Go script on a schedule.
- Frontend: one static HTML page or a tiny web app.
- Queue: your existing ticket system or a `quests` table.
- Agent: optional. Add it after deterministic rules already create useful quests.

## Pick One Business Loop

Do not start with every connector Eric mentioned. Pick one loop where a missed signal costs money or attention.

Good first loops:

- Failed payments need follow-up.
- Deals stall after a demo.
- Product signups drop below the weekly baseline.
- Support escalations sit without an owner.
- Content traffic falls after an SEO or social change.

Write the loop in one sentence:

> When [signal] happens in [source system], create [quest] for [owner], and close it when [proof] exists.

Example:

> When a Stripe invoice payment fails, create a revenue recovery quest for the owner, include the invoice, customer, attempt count, and recommended next step, and close it when the invoice is paid, voided, or marked uncollectible.

Stripe explicitly emits `invoice.payment_failed` events when invoice payment attempts fail, so that is a clean first signal.[^stripe-payment-failed]

## Design the Business Map

The map is just a table at first.

Create a table named `areas`:

| field | example | why it exists |
| --- | --- | --- |
| `area_id` | `revenue_recovery` | Stable ID for the area. |
| `name` | `Revenue recovery` | Human label. |
| `owner` | `finance_ops` | Who gets the quest. |
| `source` | `stripe` | Where the signal comes from. |
| `health_metric` | `failed_invoice_count` | The main signal. |
| `green_threshold` | `0` | Healthy range. |
| `red_threshold` | `5` | Fire range. |
| `freshness_minutes` | `60` | How stale data can get before it becomes fog. |

Create four statuses:

- `green`: signal is inside the expected range.
- `yellow`: signal needs attention soon.
- `red`: signal needs action now.
- `fog`: the data is missing or stale.

Fog matters. A dashboard that silently hides missing data teaches the team to trust a lie.

## Connect the First Source

Do the least fancy connector first.

Preferred order:

1. Webhook, if the source emits events.
2. API polling, if the source does not have the right webhook.
3. CSV export, if API access is blocked.
4. Manual spreadsheet update, if you are still proving whether anyone cares.

Eric's example mentioned systems like Stripe, HubSpot, Gong, Mixpanel, GA4, Ahrefs, and Metricool. They all expose some form of data access, but they differ in cost, authentication, rate limits, and permissions.

Useful source starting points:

- Stripe: use invoice and subscription webhooks for payment failure and recovery loops.[^stripe-events]
- HubSpot: use CRM deal APIs or deal search for stalled deal loops.[^hubspot-deals][^hubspot-search]
- Google Analytics: use the Data API `runReport` method for traffic, conversion, and event-reporting loops.[^ga-runreport]
- Mixpanel: use Query API reports or Raw Event Export depending on whether you need summarized results or raw events.[^mixpanel-query][^mixpanel-export]
- Gong: use its API to import call, transcript, scorecard, and stats data into reporting or workflows.[^gong-api]
- Ahrefs: use API v3 for data from Site Explorer, Keywords Explorer, SERP Overview, Rank Tracker, Site Audit, Brand Radar, and social media endpoints.[^ahrefs-api]
- Metricool: API access can export Metricool data and automate tasks, but plan access matters.[^metricool-api]

Do not connect all of them at once. One source, one signal, one quest.

## Normalize Events Into Signals

Every source speaks its own language. Your command center needs one boring internal shape.

Create a table named `signals`:

| field | example |
| --- | --- |
| `signal_id` | `sig_20260709_001` |
| `source` | `stripe` |
| `source_object_id` | `in_123` |
| `area_id` | `revenue_recovery` |
| `signal_type` | `invoice_payment_failed` |
| `severity` | `red` |
| `title` | `Invoice payment failed` |
| `summary` | `Customer payment failed after 2 attempts.` |
| `occurred_at` | `2026-07-09T08:30:00Z` |
| `raw_url` | `https://dashboard.stripe.com/...` |
| `payload_json` | raw source payload or a redacted subset |

The connector's job is only to get source data into this shape.

That keeps the rest of the system simple. The dashboard does not need to know Stripe, HubSpot, Gong, or Mixpanel. It only knows `signals`, `areas`, and `quests`.

## Turn Signals Into Quests

A quest is a task with context, ownership, and proof.

Create a table named `quest_rules`:

| field | example |
| --- | --- |
| `rule_id` | `failed_invoice_followup` |
| `area_id` | `revenue_recovery` |
| `when_signal_type` | `invoice_payment_failed` |
| `when_severity` | `red` |
| `quest_title_template` | `Recover failed invoice {{invoice_id}}` |
| `owner` | `finance_ops` |
| `due_hours` | `24` |
| `close_when` | `invoice_paid_or_resolved` |

Create a table named `quests`:

| field | example |
| --- | --- |
| `quest_id` | `q_20260709_001` |
| `area_id` | `revenue_recovery` |
| `signal_id` | `sig_20260709_001` |
| `title` | `Recover failed invoice in_123` |
| `owner` | `finance_ops` |
| `status` | `open` |
| `priority` | `high` |
| `next_action` | `Review failure reason and contact customer if retry is blocked.` |
| `proof_required` | `Invoice is paid, voided, or marked uncollectible.` |
| `created_at` | `2026-07-09T08:31:00Z` |
| `due_at` | `2026-07-10T08:31:00Z` |

The lazy version is a rule engine made of `if` statements.

Example:

```text
if signal_type = invoice_payment_failed and attempt_count >= 2:
  create quest "Recover failed invoice"
  assign finance owner
  due in 24 hours
```

Do not add points, badges, leaderboards, or fake motivation yet. Add those only if the team already trusts the quest queue and wants more engagement.

## Build the Screen

The first screen needs four sections.

### 1. Business Map

Show each area as a tile:

- Name.
- Owner.
- Status: green, yellow, red, or fog.
- Main metric.
- Last updated time.
- Open quests.

This is where the video-game map metaphor belongs. Keep it useful. Red areas need action. Fog areas need data repair.

### 2. Quest Queue

Show:

- Priority.
- Quest title.
- Owner.
- Due date.
- Source link.
- Proof required.
- Status.

If this is not actionable, the whole system is just a prettier dashboard.

### 3. Daily Briefing

Show:

- What changed since yesterday.
- Which areas are red.
- Which areas are fog.
- Which quests are overdue.
- Which one to do first.

### 4. Proof Log

Show closed quests and the evidence that closed them.

The proof log prevents the system from becoming theater. A quest is not done because someone clicked done. It is done because the source system changed, a check passed, or a human added the required evidence.

## Add the Agent Last

An agent is useful after the data model exists.

Use it for:

- Summarizing today's changes.
- Explaining why an area changed status.
- Drafting the quest title and next action.
- Finding likely owner from historical patterns.
- Suggesting follow-up actions.

Do not use it for:

- Silent writes to production systems.
- Sending customer messages without review.
- Changing compensation, performance, finance, or security workflows without approval.
- Deciding truth when source data is missing.

If you use Claude or Fable 5, build it as a tool-using agent. Anthropic's tool-use docs describe the pattern: the model returns a structured tool call, and your application executes the tool or lets Anthropic execute supported server tools.[^anthropic-tool-use] Anthropic also describes MCP as an open standard for connecting agents to external systems and data, which is the cleaner path if you expect many connectors.[^anthropic-mcp]

Fable 5 is positioned for long-running agentic work, but the current docs also call out cost, refusal handling, fallback behavior, and model-specific retention limits.[^fable-docs][^fable-product] That means the production design should include review, retries, logging, and a cheaper fallback model for routine work.

## Use This Prompt for the Daily Briefing

Give the model structured data, not vague access to everything.

```text
You are creating today's Business Command Center briefing.

Use only the JSON below. Do not invent missing data.

Write for an operator who needs to know what changed and what to do next.

Return:
1. One-paragraph summary.
2. Red areas and why they are red.
3. Fog areas and what data is missing.
4. Top five quests, in priority order.
5. Any risks that need human review before action.

Data:
{{business_command_center_json}}
```

The JSON should include:

```json
{
  "date": "2026-07-09",
  "areas": [],
  "signals": [],
  "open_quests": [],
  "overdue_quests": [],
  "closed_quests_since_last_briefing": []
}
```

## Start With This MVP

Build this in order:

1. Create `areas`, `signals`, `quest_rules`, and `quests`.
2. Pick one source and one signal.
3. Pull the signal manually or with the simplest connector available.
4. Create quests from deterministic rules.
5. Build one dashboard screen.
6. Generate one daily briefing from the structured JSON.
7. Review the output with the owner.
8. Track whether the quest changed the business result.

Stop there for the first version.

If the loop helps, add the second source. If the loop does not help, fix the rule or kill the idea.

## A Concrete First Build

Here is the smallest useful build that matches the command-center idea without overbuilding it.

### Loop

Failed payment recovery.

### Source

Stripe `invoice.payment_failed` webhook.

### Area

Revenue recovery.

### Signal

Invoice payment failed.

### Quest

Recover failed invoice.

### Owner

Finance, customer success, or whoever owns billing follow-up.

### Screen

One tile that shows:

- Failed invoice count.
- Total failed amount.
- Oldest unresolved failure.
- Open recovery quests.
- Data freshness.

### Close Rule

Close the quest only when:

- The invoice is paid.
- The invoice is voided.
- The invoice is marked uncollectible.
- A human records an approved exception.

That is enough to prove the system. Once that works, add stalled deals, activation drops, support escalations, or content-performance changes.

## The Part People Usually Skip

The command center is not the UI. The command center is the loop:

1. Source data changes.
2. System detects a meaningful condition.
3. A responsible owner gets a clear quest.
4. The owner acts.
5. The system verifies the result.
6. The briefing explains what changed.

If you have that loop, the interface can be ugly and still useful.

If you do not have that loop, the interface can be beautiful and still useless.

## Sources

[^stripe-payment-failed]: Stripe Docs, "Using webhooks with subscriptions." https://docs.stripe.com/billing/subscriptions/webhooks
[^stripe-events]: Stripe API Reference, "Types of events." https://docs.stripe.com/api/events/types
[^hubspot-deals]: HubSpot Developers, "CRM API - Deals." https://developers.hubspot.com/docs/api-reference/legacy/crm/objects/deals/guide
[^hubspot-search]: HubSpot Developers, "CRM search." https://developers.hubspot.com/docs/api-reference/legacy/crm/search-the-crm
[^ga-runreport]: Google Analytics Data API, "Method: properties.runReport." https://developers.google.com/analytics/devguides/reporting/data/v1/rest/v1beta/properties/runReport
[^mixpanel-query]: Mixpanel Docs, "Query API overview." https://docs.mixpanel.com/reference/query-api
[^mixpanel-export]: Mixpanel Docs, "Download Data." https://docs.mixpanel.com/reference/raw-event-export
[^gong-api]: Gong Help Center, "What the Gong API provides." https://help.gong.io/docs/what-the-gong-api-provides
[^ahrefs-api]: Ahrefs for Developers, "Introduction." https://docs.ahrefs.com/en/api/docs/introduction
[^metricool-api]: Metricool Help Center, "API Access: Export your Metricool data to other tools and automate tasks." https://help.metricool.com/api-access-export-your-metricool-data-to-other-tools-and-automate-tasks-x8ln5
[^anthropic-tool-use]: Anthropic Docs, "Tool use with Claude." https://platform.claude.com/docs/en/agents-and-tools/tool-use/overview
[^anthropic-mcp]: Anthropic, "Introducing the Model Context Protocol." https://www.anthropic.com/news/model-context-protocol
[^fable-docs]: Anthropic Docs, "Introducing Claude Fable 5 and Claude Mythos 5." https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5
[^fable-product]: Anthropic, "Claude Fable." https://www.anthropic.com/claude/fable
