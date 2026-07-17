# Generated Asset Publication

The README stats card and contribution grid are generated automatically, but automation does not push generated content to `main` and never merges its own pull requests.

## Trust Boundary

| Asset | Generation | Publication branch | Exact allowed path |
| --- | --- | --- | --- |
| README stats | Third-party action in a read-only job, followed by validation | `automation/github-stats` | `assets/github-stats.svg`, `README.md` |
| Contribution grid | Repository script with response fixtures and validation | `automation/contribution-grid` | `contribution-grid.svg`, `contribution-grid-mobile.svg`, `README.md` |

The publication step starts from a clean checkout, validates the generated output, rejects any unexpected repository path, commits only the allow-listed assets and their adjacent text summary, and creates or updates a pull request. Reused automation branches are updated with an explicit force-with-lease against the observed remote SHA. Images and text are derived from the same validated response in one commit so they cannot drift independently.

The repository allows `GITHUB_TOKEN` to create pull requests while keeping the default token permission read-only. Only the two trusted publication jobs request `contents: write` and `pull-requests: write`. The publication helper contains no approval or merge operation. GitHub may require a maintainer to approve the validation run on a pull request opened by `GITHUB_TOKEN`.

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
2. Confirm the diff contains only the documented asset path.
3. Inspect the rendered asset and the adjacent profile context.
4. Wait for the required `validate` check.
5. Merge manually. Never add an automation merge step or a broad GitHub Actions bypass.

If generation or validation fails, no branch or pull request is updated and the last-known-good asset remains on `main`.

## Rollback

To roll back the governance change, disable or delete the `Protect main` ruleset, restore direct-push workflow steps from repository history, and set `can_approve_pull_request_reviews` to `false`. Keep the repository default workflow permission `read`. Record the before/after API values in the tracking issue whenever this path changes.
