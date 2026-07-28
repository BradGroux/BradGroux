# Repository Guidance

## Profile README

- `README.md` is public profile copy. Keep it direct, practical, and public-safe.
- The canonical source for the `Media` section is the [Media Appearances YouTube playlist](https://www.youtube.com/playlist?list=PLk7BUXVNUhjoRns93lxQ7pUY7SkMAIfR1).
- When refreshing `Media`, fetch the live playlist at runtime. Do not rely on a previous chat, cached list, or memory.
- Include every public playlist entry between `<!-- media:start -->` and `<!-- media:end -->`.
- Use the playlist video title, canonical video URL, publishing outlet or channel, and publication date. Normalize obvious whitespace only.
- Sort entries newest first by publication date. If dates are unavailable, preserve playlist order for those entries.
- Keep the playlist link in the section introduction and verify every video link before publishing.
- Keep the complete appearance list inside the existing `<details>` block so the public profile stays compact.
- Update the appearance count in the `<summary>` whenever the playlist changes.

## Contribution Calendar

- `.github/scripts/generate-grid.sh` is the source of truth for `contribution-grid.svg`.
- `.github/workflows/update-grid.yml` regenerates the asset daily. Never hand-edit only the generated SVG.
- Keep the Tokyo Night purple palette and visible daily contribution counts unless Brad explicitly requests another design.
- After generator changes, run `.github/tests/test-contribution-grid.sh`, generate the live asset, validate the SVG, and visually inspect the rendered result.
