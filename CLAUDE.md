# TVBS Skills (Public)

This repo is the **public** Claude Code Plugin Marketplace for TVBS AI Team's open-source agent skills. Each plugin is installable via `/plugin marketplace add TVBS-AI/tvbs-skills`.

## Project Structure

```
tvbs-skills/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace manifest
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/
│       │   └── plugin.json # Plugin manifest
│       ├── CHANGELOG.md    # Release notes
│       └── skills/
│           └── <skill-name>/
│               ├── SKILL.md
│               └── references/   # Optional supporting docs
```

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
2. **Update `CHANGELOG.md`** in `plugins/<plugin>/` — add entry under `[Unreleased]` or a new version header
3. **Commit** with version in message: `feat(team-wiki): add tag suggestions v0.2.0`
4. If the plugin exists in both repos (`agent-skills` and `tvbs-skills`), sync both and bump versions together

### CHANGELOG.md Format

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

## [0.2.0] - 2026-08-11
### Added
- Tag suggestion list with Chinese labels for upload flow
- `tags` field in upload curl command

## [0.1.0] - 2026-07-01
### Added
- Initial release
```

Sections to use: `Added`, `Changed`, `Fixed`, `Removed`

## Adding a New Plugin Checklist

1. Create directory: `plugins/<plugin>/.claude-plugin/plugin.json` and `plugins/<plugin>/skills/<skill>/SKILL.md`
2. Fill `plugin.json` with `name`, `version` (start at `0.1.0`), `description`, `author`
3. Fill `SKILL.md` frontmatter (`name` matches its directory, `description` is one line)
4. Add `references/` files under the skill dir if needed; link with relative paths `[references/file.md](references/file.md)`
5. Register in `.claude-plugin/marketplace.json` — add an entry under `plugins[]` with `source.path: "plugins/<plugin>"`
6. Create `plugins/<plugin>/CHANGELOG.md` with initial `[0.1.0]` entry
7. Update `README.md` — add row to the **Available Skills** table
8. Commit: `feat: add <plugin> for <project-name>`

## Git Conventions

- Commit messages: [Conventional Commits](https://www.conventionalcommits.org/) in English
- `feat:` for new skills or features
- `fix:` for bug fixes
- `docs:` for documentation only changes
- `chore:` for maintenance tasks

## Repo Split — Where to Put a New Skill

There are two skill repos. Decide before creating any plugin:

| Repo | Visibility | Path | When to use |
|------|-----------|------|-------------|
| `TVBS-AI/tvbs-skills` (this repo) | **Public** | `/Users/joecwu/projects/tvbs/tvbs-skills` | Skills with no internal information — safe to share publicly |
| `TVBS-AI/agent-skills` | **Private** | `/Users/joecwu/projects/tvbs/agent-skills` | Skills that reference internal APIs, endpoints, system architecture, or TVBS-internal details |

**Decision rule:** Does the skill mention any internal URL, API key format, internal system name, or TVBS-only detail?
- Yes → **agent-skills only**
- No → **tvbs-skills only**
- Needed in both → **sync to both repos**, bump versions together

### Plugins currently synced across both repos

- `my-wiki` — synced
- `team-wiki` — synced

When modifying a synced plugin, always update **both repos** in the same commit session and keep version numbers identical.

## Important Notes

- Skills are **read-only tools** — they provide instructions and context to AI agents, they do not execute code
- Each skill's `SKILL.md` is the single source of truth for that skill's behavior
- This repo contains only **public-safe** skills — no internal API keys, internal endpoints, or TVBS-internal system details
