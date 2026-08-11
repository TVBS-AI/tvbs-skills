# TVBS Skills (Public)

This repo is the **public** Claude Code Plugin Marketplace for TVBS AI Team's open-source agent skills.

## Version Management

### Semantic Versioning

All plugins follow [Semantic Versioning](https://semver.org/): `MAJOR.MINOR.PATCH`

| Bump | When |
|------|------|
| `PATCH` | Typo fixes, wording clarifications, example corrections — no behavior change |
| `MINOR` | New features, new parameters, new tag lists, flow improvements, backward-compatible additions |
| `MAJOR` | Breaking changes: Worker redeployment required, env variable structure changed, upload API changed |

### Release Checklist (every skill update)

When `SKILL.md` or any plugin file is modified:

1. **Bump version** in `plugins/<plugin>/.claude-plugin/plugin.json`
2. **Update `CHANGELOG.md`** in `plugins/<plugin>/` — add a new version header with today's date
3. **Commit** with version in message: `feat(team-wiki): add tag suggestions v0.2.0`
4. If the plugin exists in both repos (`agent-skills` and `tvbs-skills`), sync both and bump versions together

### CHANGELOG.md Format

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

## [0.2.0] - 2026-08-11
### Added
- Tag suggestion list with Chinese labels for upload flow

## [0.1.0] - 2026-07-01
### Added
- Initial release
```

Sections to use: `Added`, `Changed`, `Fixed`, `Removed`

## Adding a New Plugin Checklist

1. Create directory: `plugins/<plugin>/.claude-plugin/plugin.json` and `plugins/<plugin>/skills/<skill>/SKILL.md`
2. Fill `plugin.json` with `name`, `version` (start at `0.1.0`), `description`, `author`
3. Fill `SKILL.md` frontmatter (`name` matches its directory, `description` is one line)
4. Add `references/` files under the skill dir if needed
5. Register in `.claude-plugin/marketplace.json`
6. Create `plugins/<plugin>/CHANGELOG.md` with initial `[0.1.0]` entry
7. Update `README.md` — add row to the **Available Skills** table
8. Commit: `feat: add <plugin> for <project-name>`

## Git Conventions

- Commit messages: [Conventional Commits](https://www.conventionalcommits.org/) in English
- `feat:` for new skills or features
- `fix:` for bug fixes
- `docs:` for documentation only changes
- `chore:` for maintenance tasks

## Important Notes

- Skills are **read-only tools** — they provide instructions and context to AI agents
- This repo contains only **public-safe** skills — no internal API keys or TVBS-internal system details
