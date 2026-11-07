# TVBS Skills

TVBS AI Team 開源的 Claude Code Agent Skills 集合，可透過 Claude Code Plugin Marketplace 安裝。

## Quick Start

在 Claude Code 中執行：

```
/plugin marketplace add TVBS-AI/tvbs-skills
```

## Available Skills

| Plugin | Skill | Description |
|--------|-------|-------------|
| [my-wiki](my-wiki/) | `my-wiki` | Personal HTML report bookmark wiki on Cloudflare Worker + R2 + KV. Auto-guides first-time setup; publish any HTML report in one step. |
| [team-wiki](team-wiki/) | `team-wiki` | Team HTML report wiki on Cloudflare Worker + R2 + KV. Multiple teams share one Worker; per-author filtering and cross-member deletion. Zero Trust protected. |
| [company-wiki](plugins/company-wiki/) | `wiki-publish` | TVBS company HTML report wiki (wiki.tvbs.ai). Connect Claude Code / Codex with one browser approval, write readable reports (laid out with the html-report skill when installed), then publish, search, organize, trash and restore them, and manage teams — anything the web can do. |
| [html-report](plugins/html-report/) | `html-report` | Turn an answer, research result, comparison or incident review into one readable HTML report. The agent writes a short Markdown draft; the bundled CLI (adapted from answer-me-with-html, MIT) lays it out with diagrams, charts and light/dark themes into a single offline file. Recommended for company-wiki users. |
| [roomcord](plugins/roomcord/) | `roomcord-agent-config` | Configure and manage RoomCord (WorkCord is RoomCord for Enterprise) room agents and custom agents — instructions, skills, schedules, API credentials — with your own login via the workcord CLI. Looks up exact commands from the CLI's live help. |

## License

MIT
