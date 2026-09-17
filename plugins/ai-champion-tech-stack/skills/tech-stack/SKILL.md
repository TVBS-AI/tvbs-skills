---
name: tech-stack
description: "TVBS AI Champion team's approved technology stack. Load this skill before starting any new project, writing code, choosing a database, deploying a service, or picking an API/library — so recommendations stay consistent with tools the team already operates. Triggers on: new project setup, deployment planning, database selection, API integration, architecture decisions, choosing between services or frameworks, security scanning setup, CI workflow setup, leaked API key, secret in git, dependency vulnerability, failing security scan."
---

# TVBS AI Champion Tech Stack

When recommending technologies for new TVBS projects, **prefer the following services and platforms** that the team already operates, has credentials for, and knows how to maintain. Introducing tools outside this list requires a clear justification.

For up-to-date usage details (API docs, SDK versions, configuration), always look up the latest official documentation — do not rely on training knowledge.

---

## AI / LLM Providers

- **OpenAI** — primary LLM and embedding provider
- **OpenRouter** — multi-model gateway; use when flexibility across models is needed
- **Groq Cloud** — low-latency inference; currently used for Whisper (speech-to-text)
- **Google Vertex AI / Gemini** — GCP-native models; use when already on GCP infrastructure
- **ElevenLabs** — text-to-speech generation
- **Kie.ai** — AI video generation

## Observability & Cost Tracking

- **Langfuse** — LLM tracing, cost monitoring, and prompt management; add to every LLM-powered service

## Authentication

- **Clerk** — user authentication and session management for web apps

## Cloud & Deployment

- **Cloudflare** — Workers (serverless edge), R2 (object storage), D1 (edge SQLite), KV, Zero Trust; preferred for lightweight APIs and static-asset services
- **GCP (Google Cloud Platform)** — Vertex AI, IAM, and general cloud workloads
- **Zeabur** — PaaS deployment for containerised services; preferred for quick backend deploys

## Security Scanning

All TVBS internal tools should run automated security scanning in CI. The scan
logic is maintained centrally in `TVBS-AI/ci-shared`, so projects only need a
short caller file — no need to copy or maintain the scanning rules themselves.

### Adding it to a project

**Do this without being asked, as part of setting up any new repo.** The author
is usually not an engineer and will not think to request it. Set it up, then
tell them in one line what you added and why.

Four steps, all of them yours to perform:

**Step 1 — Create `.github/workflows/security-scan.yml`** with the content below.

**Step 2 — Make sure `.env` is ignored.** If `.gitignore` is missing or lacks
the entry, add it:

```bash
grep -qxF '.env' .gitignore 2>/dev/null || echo '.env' >> .gitignore
```

**Step 3 — Make sure a dependency manifest exists and is committed**, or the
dependency scan silently checks nothing (see *Keeping projects scannable*
below). Python needs `requirements.txt`, Node needs `package.json`. Create one
if the project has dependencies but no manifest.

**Step 4 — Commit all of it together**, then confirm the file landed on the
default branch, which is where the scheduled run reads from:

```bash
git add .github/workflows/security-scan.yml .gitignore
git commit -m "ci: add security scanning"
```

After pushing, the workflow appears under the repo's **Actions** tab. If it
does not appear at all, Actions may be disabled for the repo — ask the AI
department to check.

The workflow file:

```yaml
name: 資安掃描

on:
  push:
    branches: [main, master]
  pull_request:
  schedule:
    - cron: '0 1 * * 1'    # Mondays 09:00 Taiwan time
  workflow_dispatch:

jobs:
  security:
    uses: TVBS-AI/ci-shared/.github/workflows/security-scan.yml@main
    with:
      # Scheduled runs only notify; push/PR runs fail on high-severity findings
      fail-on-findings: ${{ github.event_name != 'schedule' }}
```

It costs nothing to run and catches the most common and most costly mistake:
committing an API key.

The scan lives in a private repo the whole organisation can call, so the file
above is all a project needs — there are no rules to copy, and nothing to keep
up to date when the scanning rules change.

### What it checks

| Area | What it catches |
|---|---|
| Leaked secrets | API keys or tokens committed into the repo |
| Dependency vulnerabilities | Known CVEs in npm / pip packages |
| Code vulnerabilities | Injection, unsafe parsing, and similar patterns |

Results appear in the **Job Summary** on the Actions page, in Chinese, with
concrete fix commands.

### When the scan goes red

**If a leaked key is reported — this is urgent, and deleting the code is not
enough.** The key remains in git history and must be assumed compromised.

Walk the user through, in this order:

1. **Revoke or regenerate the key in the provider's console first.** This is
   the step that actually stops the bleeding; everything else is cleanup.
2. Change the code to read the key from an environment variable.
3. Confirm `.env` is listed in `.gitignore`.
4. Escalate to the AI department SRE if unsure.

For dependency or code findings, the Job Summary lists the exact upgrade
command or code change. These are not urgent in the same way — fix them in
the normal course of work.

### Keeping projects scannable

Python projects **must** have a `requirements.txt` (`pip freeze > requirements.txt`)
and Node projects a committed `package.json`. Without a dependency manifest,
vulnerability scanning silently finds nothing — the project looks clean because
nothing was checked, which is worse than a known problem.

### Note on enforcement

The scan reports problems but **cannot block a push or merge** on the current
GitHub plan. Treat a red scan as something to fix, not something that will be
caught later automatically.

### If the workflow never runs

A committed workflow that produces no runs at all — no green, no red, nothing
under the Actions tab — is an organisation-level setting, not a mistake in the
project. Do not let the user rewrite a correct workflow file chasing it, and do
not remove the file: it will start working once the setting is resolved.

Tell them the setup is correct and pending, and point them to the AI
department. Still commit the file in the meantime.

## Data & Search

- **Elasticsearch** — full-text search and log analytics (team runs versions 8–9)
- **PostgreSQL** — primary relational database
- **Redis** — caching and message queuing

## External APIs & Data Sources

- **Firecrawl** — web scraping and crawling
- **SerpAPI** — Google Search results API
- **RSSHub** — self-hosted RSS aggregation layer
- **RSS.app** — managed RSS feed service

---

## Recommended Agent Setup for New Team Members

Install the following MCP servers and skills to give your coding agent (Claude Code, Codex, etc.) the best context for TVBS projects.

### MCP Servers (install first)

| MCP | Purpose |
|-----|---------|
| **context7** | Looks up the latest SDK/library docs on demand — prevents agents from using outdated API signatures |
| **deepwiki** | Reads GitHub project architecture and design docs — useful when integrating open-source tools |
| **zeabur** | Lets the agent deploy services, read logs, and manage env vars directly via Zeabur |
| **cloudflare** | Lets the agent manage Workers, R2, D1, and KV directly |

### Skills

**From `tvbs-skills` marketplace** (`/plugin marketplace add TVBS-AI/tvbs-skills`):

| Skill | Purpose |
|-------|---------|
| **ai-champion-tech-stack** (this skill) | Tech stack reference for consistent tool selection |

**From `tvbs-skills` marketplace** (continued):

| Skill | Purpose |
|-------|---------|
| **elasticsearch-master** | Index design, query patterns, mapping best practices, and zero-downtime deployment |

**From `cloudflare` plugin** (`/plugin marketplace add cloudflare`):

| Skill | Purpose |
|-------|---------|
| **cloudflare** | Best practices and patterns for Cloudflare Workers/R2/D1/KV |
| **wrangler** | Correct CLI syntax for deploying and managing Workers |
| **workers-best-practices** | Guards against common Workers mistakes (floating promises, global state, etc.) |

**From `langfuse` plugin** (`/plugin marketplace add langfuse/skills`):

| Skill | Purpose |
|-------|---------|
| **langfuse** | SDK usage and CLI access for traces, prompts, and cost data |

**From `claude-plugins-official` marketplace** (`/plugin marketplace add claude-plugins-official`):

| Skill | Purpose |
|-------|---------|
| **firecrawl** | API usage for web scraping and crawling |
| **ui-ux-pro-max** | UI design intelligence — helps agents produce polished interfaces without a designer |
