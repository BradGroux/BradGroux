# Repository Guidance

## Profile README

- `README.md` is public profile copy. Keep it direct, practical, and public-safe.
- The canonical source for the `Media` section is the [Media Appearances YouTube playlist](https://www.youtube.com/playlist?list=PLk7BUXVNUhjoRns93lxQ7pUY7SkMAIfR1).
- When refreshing `Media`, fetch the live playlist at runtime. Do not rely on a previous chat, cached list, or memory.
- Include every public playlist entry between `<!-- media:start -->` and `<!-- media:end -->`.
- Use the playlist video title, canonical video URL, publishing outlet or channel, and publication date. Normalize obvious whitespace only.
- Sort entries newest first by publication date. If dates are unavailable, preserve playlist order for those entries.
- Keep the playlist link in the section introduction and verify every video link before publishing.
- Keep the complete appearance list visible. Do not collapse it behind a `<details>` block.
- Keep `Connect` as one centered row of compact inline link boxes. Do not replace it with a table, image badges, spacer images, or width-specific positioning.

## Contribution Calendar

- `.github/scripts/generate-grid.sh` is the source of truth for `contribution-grid.svg`.
- `.github/workflows/update-grid.yml` regenerates the asset daily. Never hand-edit only the generated SVG.
- Keep the Tokyo Night purple palette, visible daily contribution counts, and one continuous 53-week row unless Brad explicitly requests another design.
- After generator changes, run `.github/tests/test-contribution-grid.sh`, generate the live asset, validate the SVG, and visually inspect the rendered result.
