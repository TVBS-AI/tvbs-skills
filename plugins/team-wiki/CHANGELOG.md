# Changelog

## [0.2.0] - 2026-08-11
### Added
- Tag suggestion list with Chinese labels (類型 + 環節 兩個維度)
- `tags` field (`-F "tags=<tag1,tag2>"`) in upload curl command
- Tag filter UI on team index page (author filter + tag filter 雙維度)
- Author attribution shown on each report card
- Cross-member deletion with API key confirmation modal
- Taiwan timezone timestamp (YYYY-MM-DD HH:mm) on all reports

## [0.1.0] - 2026-08-01
### Added
- Initial release: team HTML report wiki on Cloudflare Worker + R2 + KV
- Multi-team support via single Worker, isolated per team
- Zero Trust protection with `/api/*` bypass for upload
- Per-team API key authentication
- Dynamic member discovery from uploaded reports
