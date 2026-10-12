# Changelog

## [0.5.1] - 2026-10-12

### Fixed
- `plugin.json` `author` is now an object (`{ "name": ... }`), as required by the Claude Code plugin manifest schema; `claude plugin validate` previously failed on it

## [0.5.0] - 2026-09-17

### Changed
- Security scanning is now something the agent sets up unprompted during new-repo creation, not a suggestion to relay: four concrete steps covering the workflow file, the `.env` ignore entry, the dependency manifest, and the commit

### Added
- Guidance for when the workflow produces no runs at all — an organisation-level setting, so the agent should stop the user from rewriting a correct file or deleting it

## [0.4.0] - 2026-09-17

### Added
- Security Scanning section: how to add the shared CI scan to a project, what it checks, and how to respond when it goes red
- Leaked-key response procedure emphasising that revoking the key in the provider's console comes first — deleting the code leaves it in git history
- Dependency manifest requirement (`requirements.txt` / `package.json`), without which vulnerability scanning silently finds nothing
- Security trigger keywords in `description` so the skill loads at CI setup and when a scan fails

## [0.3.0] - 2026-08-25

### Changed
- Fix skill installation sources: langfuse points to `langfuse/skills`, elasticsearch-master points to `tvbs-skills`

## [0.2.0] - 2026-08-25

### Added
- Recommended agent setup section: MCP servers (context7, deepwiki, zeabur, cloudflare) and skills for new team members

## [0.1.1] - 2026-08-25

### Changed
- Improve skill description to trigger on implicit tech-selection scenarios (new project, writing code, deployment) not just explicit "choose technology" requests

## [0.1.0] - 2026-08-25

### Added
- Initial release with TVBS AI Champion approved tech stack
