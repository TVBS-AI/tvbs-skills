---
name: tech-stack
description: "TVBS AI Champion team's approved technology stack. Load this skill before starting any new project, writing code, choosing a database, deploying a service, or picking an API/library — so recommendations stay consistent with tools the team already operates. Triggers on: new project setup, deployment planning, database selection, API integration, architecture decisions, choosing between services or frameworks."
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

### Skills (install via `tvbs-skills` marketplace)

| Skill | Purpose |
|-------|---------|
| **ai-champion-tech-stack** (this skill) | Tech stack reference for consistent tool selection |
| **cloudflare** | Best practices and patterns for Cloudflare Workers/R2/D1/KV |
| **wrangler** | Correct CLI syntax for deploying and managing Workers |
| **workers-best-practices** | Guards against common Workers mistakes (floating promises, global state, etc.) |
| **elasticsearch-master** | Index design, query patterns, and mapping best practices |
| **langfuse** | SDK usage and CLI access for traces, prompts, and cost data |
| **firecrawl** | API usage for web scraping and crawling |
| **ui-ux-pro-max** | UI design intelligence — helps agents produce polished interfaces without a designer |
