This tenant has access to the TVBS Trends news-intelligence system through the
`tvbs-trends` CLI. Use it when the user asks about trending topics, news
opportunities, keyword volume, or wants to know what to cover next.

The CLI reads `TVBS_TRENDS_KEY` from the environment — this is a managed
stub; the Hub egress proxy supplies the real credential transparently. Never
print, log, or forward the value of `TVBS_TRENDS_KEY`.

Quick reference (full guidance in `skills/tvbs-trends/SKILL.md`):

- Breaking news opportunities:  `tvbs-trends opportunities --window-hours 4`
- Today's hot topics (fast):    `tvbs-trends latest --window-hours 24`
- Keyword volume trend:         `tvbs-trends timeline --keyword <詞>`
- Newsroom digest (formatted):  `tvbs-trends digest --format plain --pretty`

Always check `meta.staleness_seconds` and `meta.warnings` in the JSON
envelope before quoting data to the user. Prefer snapshot commands (`latest`,
`timeline`, `snapshot`) over live crawl commands (`trending`, `interest`)
unless the user explicitly needs real-time data.
