# Changelog

## [0.1.0] - 2026-10-20
### Added
- Initial release: `roomcord-agent-config` skill for configuring RoomCord (and WorkCord, RoomCord for Enterprise) room agents and custom agents with the user's own login
- Permission boundary: user login only — no JWT signing secret, impersonation, internal keys, or backend admin APIs; API keys never pass through the coding agent
- Workflow: check environment and login, find room and agent by name, pick the change method, confirm before mutating, verify by reading back and running the agent
- Commands are looked up from the CLI's `--help` and README at run time instead of being hardcoded
