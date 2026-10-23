# Changelog

## [0.4.0] - 2026-10-22
### Added
- Personal sign-in: `auth login` (agent shows the person a link and code; they approve with their TVBS account; the token never passes through the conversation), `auth status`, `auth logout`. Team API keys still work.
- `topic` (surging trends by category or keyword, flagged with TVBS coverage) and `momentum` (rising / stable / falling search interest; volume only, not sentiment).
- `news_available` and the Google-news warning: since 2026-10-21 Google Trends no longer serves trend news, so exclusive / follow-up classification is paused and empty `news` does not mean no coverage.
### Changed
- Always run `npx -y @tvbs-ai/tvbs-trends@latest` so a cached older CLI is never used.
- Agent login: handle `already_connected`, and finish with a second non-blocking `auth login --no-wait`.
- Corrected defaults: `interest --geo` is worldwide; `snapshot --window-hours` has none; `--num-news` only applies to trending / opportunities / topic.
- `--base-url` must be an https origin, and `TVBS_TRENDS_API_KEY` is only sent to TVBS servers (`*.tvbs.ai`) and localhost.
### Removed
- MCP: the remote MCP endpoint was retired; use the CLI, or REST when a shell is not available.

## [0.1.0] - 2026-08-01
### Added
- Initial release: query TVBS Google Trends system
- Rising keywords, news opportunity detection (exclusive scoops / urgent follow-ups)
- Keyword volume trends and historical snapshots
- Supports npm CLI (npx @tvbs-ai/tvbs-trends), MCP, and REST fallbacks
