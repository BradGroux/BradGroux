# Generated Asset Publication

The README stats card and contribution grid are refreshed together once daily at 06:00 UTC, with manual dispatch available when needed. Automation does not push generated content to `main` and never merges its own pull requests.

## Trust Boundary

| Asset | Generation | Publication branch | Exact allowed path |
| --- | --- | --- | --- |
| README stats | Third-party action in a read-only job, followed by validation | `automation/profile-activity` | `assets/github-stats.svg`, `README.md` |
| Contribution grid | Repository script in a separate read-only job, with response fixtures and validation | `automation/profile-activity` | `contribution-grid.svg`, `contribution-grid-mobile.svg`, `README.md` |

The two generation jobs must both succeed before the single publication job runs. Publication starts from a clean checkout, revalidates the complete generated bundle, rejects any unexpected repository path, commits only the allow-listed assets and their adjacent text summaries, and creates or updates one pull request. Reused automation branches are updated with an explicit force-with-lease against the observed remote SHA. Images and text are derived from the same validated responses in one commit so they cannot drift independently.

The repository allows `GITHUB_TOKEN` to create pull requests while keeping the default token permission read-only. Only the trusted publication job requests `contents: write` and `pull-requests: write`; both network-facing generation jobs are read-only and disable persisted checkout credentials. The publication helper contains no approval or merge operation. GitHub may require a maintainer to approve the validation run on a pull request opened by `GITHUB_TOKEN`.

## Freshness and Concurrency

The intended freshness target is one attempted refresh per day. A manual dispatch can request another run, but repository-wide workflow concurrency queues it behind any active refresh so two publications cannot race. Each job has a ten-minute timeout.

If either provider fails, publication is skipped and the last-known-good profile remains on `main`. If both providers succeed but none of the four allow-listed files changes, the publisher exits without a commit or pull request update. Upstream availability and the required human merge mean the public data can be older than 24 hours; safety takes priority over a false freshness claim.

Review the bot-commit rate on or after August 16, 2026 by comparing the 30 days before and after consolidation. Record scheduled attempts, successful generated pull requests, and merged generated commits in issue #16 before considering the cadence review complete.

## Main Ruleset

The active `main` ruleset is configured outside the repository after the validation workflow is merged and observed. It requires:

- all changes to arrive through a pull request;
- the GitHub Actions `validate` check to pass against the current head;
- review conversations to be resolved;
- linear history;
- branch deletion and force pushes to remain blocked.

There are no bypass actors, including for administrators or GitHub Actions. The required approving-review count is zero because this is a single-maintainer profile repository; the pull request record, required validation, and manual merge are the proportionate gate. Administrators cannot push around the ruleset.

## Maintainer Flow

1. Open the generated pull request and approve its workflow run if GitHub requests approval.
2. Confirm the diff contains only the documented asset paths.
3. Inspect the rendered asset and the adjacent profile context.
4. Wait for the required `validate` check.
5. Merge manually. Never add an automation merge step or a broad GitHub Actions bypass.

If generation or validation fails, no branch or pull request is updated and the last-known-good asset remains on `main`.

## Rollback

To roll back the governance change, disable or delete the `Protect main` ruleset, restore the prior workflow from repository history, and set `can_approve_pull_request_reviews` to `false`. Keep the repository default workflow permission `read`. Record the before/after API values in the tracking issue whenever this path changes.
