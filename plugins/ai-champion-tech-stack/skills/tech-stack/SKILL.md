---
name: tech-stack
description: "TVBS AI Champion team's approved technology stack. Use this skill when helping TVBS colleagues build new tools or choose technologies, so agents recommend platforms and services already adopted by the team rather than introducing unfamiliar ones. Triggers on: tech selection, architecture decisions, starting a new project, choosing a database/API/service, deployment decisions."
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

## Media & Content

- **ElevenLabs** — (also listed under AI; text-to-speech)
- **Kie.ai** — (also listed under AI; video generation)
