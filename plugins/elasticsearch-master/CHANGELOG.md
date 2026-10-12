# Changelog

## [0.1.1] - 2026-10-12

### Fixed
- `plugin.json` `author` is now an object (`{ "name": ... }`), as required by the Claude Code plugin manifest schema; `claude plugin validate` previously failed on it

## [0.1.0] - 2026-08-25

### Added
- Initial release with TVBS Elasticsearch best practices: index versioning, alias management, mapping design, semantic search, ingest pipelines, and zero-downtime deployment
