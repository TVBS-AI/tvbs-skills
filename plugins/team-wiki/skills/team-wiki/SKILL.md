---
name: team-wiki
description: 團隊 HTML report 書籤 wiki，由 Cloudflare Worker + R2 + KV 驅動。多個 team 共用一個 Worker，各 team 成員互相可見彼此發佈的 report，支援依成員過濾與跨成員刪除，並有 Zero Trust 保護。當使用者提到「上傳 report」、「發布 report」、「publish」、「team wiki」、「team-wiki」時觸發。
---

# Team Wiki — 團隊 Report 書籤

這個 skill 讓團隊成員在任何地方用一句話把 HTML report 上傳到團隊的 Cloudflare Worker wiki，同 team 成員可互相查看與管理彼此的 report。

**架構：** Cloudflare Worker + R2（存 HTML 檔案）+ KV（書籤清單 + team 設定）+ 自訂網域 + Zero Trust

---

## 第一步：偵測狀態

```bash
echo "WORKER_URL=${TEAM_WIKI_URL:-NOT_SET}"
```

- 輸出 `NOT_SET` → 詢問使用者身份：
  - 「你是管理員（負責部署）還是一般成員（已有 URL 和 API Key）？」
  - 管理員 → 執行 **[Setup 流程]**
  - 一般成員 → 執行 **[成員設定流程]**
- 有值 → 執行 **[上傳流程]**

---

## [Setup 流程] 管理員第一次部署

### Prerequisites 確認

```bash
npx wrangler whoami 2>&1 | head -5
```

若未登入，請使用者先執行：
```
! npx wrangler login
```

### Step 1：詢問設定（每次一個問題）

1. **Worker 名稱**（必填）— 例如 `my-team-wiki`，只用英數字和連字號
2. **自訂網域**（必填）— 例如 `wiki.example.com`，必須是你在 Cloudflare 管理的網域
3. **Team 清單**（必填）— 依序詢問每個 team：
   - Team ID（slug，例如 `team-a`）
   - Team 顯示名稱（例如 `Team Alpha`）
   - 成員列表（逗號分隔，例如 `alice,bob,carol`）
   - 重複直到使用者說「完成」
4. **每個 Team 的 API Key** — 每個 team 各自一把，用 `openssl rand -hex 32` 產生

### Step 2：產生 Worker 專案

在 `~/team-wiki-worker` 目錄（或使用者指定的位置）產生以下檔案：

#### `package.json`
```json
{
  "name": "team-wiki-worker",
  "private": true,
  "scripts": {
    "deploy": "wrangler deploy"
  },
  "devDependencies": {
    "wrangler": "^4.0.0",
    "typescript": "^5.0.0",
    "@cloudflare/workers-types": "^4.0.0"
  }
}
```

#### `tsconfig.json`
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src/**/*.ts"]
}
```

#### `wrangler.jsonc`
（`<WORKER_NAME>`、`<CUSTOM_DOMAIN>`、`<KV_ID>` 替換為實際值；`TEAM_*` vars 由管理員填入）
```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "<WORKER_NAME>",
  "main": "src/index.ts",
  "compatibility_date": "2026-05-01",
  "compatibility_flags": ["nodejs_compat_v2"],
  "workers_dev": false,
  "routes": [
    {
      "pattern": "<CUSTOM_DOMAIN>",
      "custom_domain": true
    }
  ],
  "kv_namespaces": [
    {
      "binding": "REPORTS_KV",
      "id": "<KV_ID>"
    }
  ],
  "r2_buckets": [
    {
      "binding": "REPORTS_R2",
      "bucket_name": "<WORKER_NAME>-reports"
    }
  ],
  "vars": {
    "TEAM_IDS": "team-a,team-b,team-c",
    "TEAM_A_NAME": "Team Alpha",
    "TEAM_B_NAME": "Team Beta",
    "TEAM_C_NAME": "Team Gamma"
  }
}
```

> API Key 不放 vars（避免明文進 git），改用 wrangler secret：
> ```bash
> echo "<KEY>" | npx wrangler secret put TEAM_A_API_KEY
> echo "<KEY>" | npx wrangler secret put TEAM_B_API_KEY
> echo "<KEY>" | npx wrangler secret put TEAM_C_API_KEY
> ```

#### `src/index.ts`
```typescript
import { handlePublish } from './handlers/publish';
import { handleDelete } from './handlers/delete';
import { handleIndex } from './handlers/index-page';
import { handleReport } from './handlers/report';
import { resolveTeamConfig, TeamConfig } from './lib/teams';

export interface Env {
  REPORTS_KV: KVNamespace;
  REPORTS_R2: R2Bucket;
  TEAM_IDS: string;
  // Per-team vars (injected dynamically via wrangler vars + secrets)
  [key: string]: unknown;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { pathname, method } = Object.assign(url, { method: request.method });

    if (pathname === '/api/publish' && method === 'POST') {
      return handlePublish(request, env);
    }

    if (pathname === '/api/delete' && method === 'DELETE') {
      return handleDelete(request, env);
    }

    // /{team}/ or /{team}
    const teamIndexMatch = pathname.match(/^\/([^/]+)\/?$/);
    if (teamIndexMatch && method === 'GET') {
      const teamId = teamIndexMatch[1];
      const teams = resolveTeamConfig(env);
      const team = teams[teamId];
      if (!team) return new Response('Team not found', { status: 404 });
      return handleIndex(request, env, teamId, team);
    }

    // /{team}/{author}/{project}/{filename}
    const reportMatch = pathname.match(/^\/([^/]+)\/([^/]+)\/([^/]+)\/([^/]+\.html?)$/);
    if (reportMatch && method === 'GET') {
      return handleReport(request, env);
    }

    return new Response('Not Found', { status: 404 });
  },
};
```

#### `src/lib/teams.ts`
```typescript
import { Env } from '../index';

export interface TeamConfig {
  name: string;
  apiKey: string;
}

export function resolveTeamConfig(env: Env): Record<string, TeamConfig> {
  const teamIds = (env.TEAM_IDS as string).split(',').map((s) => s.trim());
  const result: Record<string, TeamConfig> = {};

  for (const id of teamIds) {
    const upper = id.replace(/-/g, '_').toUpperCase();
    const name = (env[`${upper}_NAME`] as string) ?? id;
    const apiKey = (env[`${upper}_API_KEY`] as string) ?? '';
    result[id] = { name, apiKey };
  }

  return result;
}

export function authenticateTeam(
  apiKey: string,
  teams: Record<string, TeamConfig>
): string | null {
  for (const [id, config] of Object.entries(teams)) {
    if (config.apiKey && config.apiKey === apiKey) return id;
  }
  return null;
}
```

#### `src/handlers/publish.ts`
```typescript
import { Env } from '../index';
import { resolveTeamConfig, authenticateTeam } from '../lib/teams';

export interface ReportEntry {
  team: string;
  author: string;
  project: string;
  filename: string;
  title: string;
  url: string;
  createdAt: string;
}

export async function handlePublish(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get('Authorization');
  const apiKey = authHeader?.replace('Bearer ', '') ?? '';

  const teams = resolveTeamConfig(env);
  const teamId = authenticateTeam(apiKey, teams);
  if (!teamId) return new Response('Unauthorized', { status: 401 });

  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return new Response('Invalid multipart form data', { status: 400 });
  }

  const file = formData.get('file') as File | null;
  const project = formData.get('project') as string | null;
  const author = formData.get('author') as string | null;
  const title = formData.get('title') as string | null;
  const dateParam = formData.get('date') as string | null;

  if (!file || !project || !author) {
    return new Response('Missing required fields: file, project, author', { status: 400 });
  }

  const filename = file.name;
  if (!filename.endsWith('.html') && !filename.endsWith('.htm')) {
    return new Response('Only HTML files are allowed', { status: 400 });
  }

  const safeFilename = filename.replace(/[^a-zA-Z0-9-_.]/g, '-');
  const safeProject = project.replace(/[^a-zA-Z0-9-_]/g, '-').toLowerCase();
  const safeAuthor = author.replace(/[^a-zA-Z0-9-_]/g, '-').toLowerCase();
  const r2Key = `${teamId}/${safeAuthor}/${safeProject}/${safeFilename}`;

  const htmlContent = await file.arrayBuffer();
  await env.REPORTS_R2.put(r2Key, htmlContent, {
    httpMetadata: { contentType: 'text/html; charset=utf-8' },
  });

  const reportTitle = title || safeFilename.replace(/\.html?$/, '');
  const reportUrl = `/${teamId}/${safeAuthor}/${safeProject}/${safeFilename}`;
  const isValidDate = dateParam !== null && /^\d{4}-\d{2}-\d{2}$/.test(dateParam);
  const createdAt = isValidDate ? dateParam : new Date().toISOString().split('T')[0];

  const kvKey = `reports:${teamId}`;
  const existingJson = (await env.REPORTS_KV.get(kvKey)) ?? '[]';
  const reports: ReportEntry[] = JSON.parse(existingJson);

  const newEntry: ReportEntry = {
    team: teamId,
    author: safeAuthor,
    project: safeProject,
    filename: safeFilename,
    title: reportTitle,
    url: reportUrl,
    createdAt,
  };

  const updatedReports = [newEntry, ...reports.filter((r) => r.url !== reportUrl)];
  await env.REPORTS_KV.put(kvKey, JSON.stringify(updatedReports));

  const workerUrl = new URL(request.url).origin;
  return new Response(
    JSON.stringify({
      success: true,
      url: `${workerUrl}${reportUrl}`,
      indexUrl: `${workerUrl}/${teamId}/`,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } }
  );
}
```

#### `src/handlers/delete.ts`
```typescript
import { Env } from '../index';
import { resolveTeamConfig, authenticateTeam } from '../lib/teams';
import { ReportEntry } from './publish';

export async function handleDelete(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get('Authorization');
  const apiKey = authHeader?.replace('Bearer ', '') ?? '';

  const teams = resolveTeamConfig(env);
  const teamId = authenticateTeam(apiKey, teams);
  if (!teamId) return new Response('Unauthorized', { status: 401 });

  let body: { url: string };
  try {
    body = await request.json() as { url: string };
  } catch {
    return new Response('Invalid JSON body', { status: 400 });
  }

  const { url: reportUrl } = body;
  if (!reportUrl) return new Response('Missing field: url', { status: 400 });

  // Ensure the URL belongs to this team
  if (!reportUrl.startsWith(`/${teamId}/`)) {
    return new Response('Forbidden: report does not belong to your team', { status: 403 });
  }

  const r2Key = reportUrl.slice(1); // remove leading /
  await env.REPORTS_R2.delete(r2Key);

  const kvKey = `reports:${teamId}`;
  const existingJson = (await env.REPORTS_KV.get(kvKey)) ?? '[]';
  const reports: ReportEntry[] = JSON.parse(existingJson);
  const updatedReports = reports.filter((r) => r.url !== reportUrl);
  await env.REPORTS_KV.put(kvKey, JSON.stringify(updatedReports));

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}
```

#### `src/handlers/index-page.ts`
```typescript
import { Env } from '../index';
import { TeamConfig } from '../lib/teams';
import { ReportEntry } from './publish';

export async function handleIndex(
  _request: Request,
  env: Env,
  teamId: string,
  team: TeamConfig
): Promise<Response> {
  const kvKey = `reports:${teamId}`;
  const reportsJson = (await env.REPORTS_KV.get(kvKey)) ?? '[]';
  const reports: ReportEntry[] = JSON.parse(reportsJson);

  const authors = [...new Set(reports.map((r) => r.author))].sort();
  const projects = [...new Set(reports.map((r) => r.project))].sort();

  const authorButtons = authors.length > 1
    ? authors.map((a) => {
        const count = reports.filter((r) => r.author === a).length;
        return `<button class="filter-btn" data-author="${escapeHtml(a)}">${escapeHtml(a)} <span class="count">${count}</span></button>`;
      }).join('\n  ')
    : '';

  const projectButtons = projects.length > 1
    ? projects.map((p) => {
        const count = reports.filter((r) => r.project === p).length;
        return `<button class="filter-btn" data-project="${escapeHtml(p)}">${escapeHtml(p)} <span class="count">${count}</span></button>`;
      }).join('\n  ')
    : '';

  const reportItems = reports.length === 0
    ? '<p class="empty">No reports yet. Use the team-wiki skill to publish one!</p>'
    : reports.map((r) => `
      <li class="report-item" data-author="${escapeHtml(r.author)}" data-project="${escapeHtml(r.project)}">
        <div class="report-info">
          <a class="report-title" href="${escapeHtml(r.url)}" target="_blank">${escapeHtml(r.title)}</a>
          <span class="report-meta">${escapeHtml(r.createdAt)} · ${escapeHtml(r.project)}</span>
        </div>
        <div class="report-right">
          <span class="report-author">${escapeHtml(r.author)}</span>
          <button class="delete-btn" data-url="${escapeHtml(r.url)}" title="刪除">✕</button>
        </div>
      </li>`).join('\n');

  const html = `<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(team.name)} Wiki</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 2rem; }
    h1 { font-size: 1.8rem; margin-bottom: 0.25rem; color: #111; }
    .subtitle { color: #666; margin-bottom: 1.5rem; font-size: 0.9rem; }
    .filter-section { margin-bottom: 1rem; }
    .filter-label { font-size: 0.75rem; font-weight: 600; color: #888; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.4rem; }
    .filters { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-bottom: 0.75rem; }
    .filter-btn { display: inline-flex; align-items: center; gap: 0.35rem; padding: 0.3rem 0.75rem; border-radius: 99px; border: 1.5px solid #d1d5db; background: #fff; color: #555; font-size: 0.8rem; cursor: pointer; transition: all 0.15s; }
    .filter-btn:hover { border-color: #4f46e5; color: #4f46e5; }
    .filter-btn.active { background: #4f46e5; border-color: #4f46e5; color: #fff; }
    .filter-btn.active-author { background: #0891b2; border-color: #0891b2; color: #fff; }
    .filter-btn .count { font-size: 0.72rem; opacity: 0.8; }
    .all-btn { border-color: #9ca3af; }
    .report-list { list-style: none; display: flex; flex-direction: column; gap: 0.6rem; margin-top: 1rem; }
    .report-item { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; padding: 0.9rem 1.1rem; display: flex; align-items: center; justify-content: space-between; transition: box-shadow 0.15s; }
    .report-item:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .report-item.hidden { display: none; }
    .report-info { display: flex; flex-direction: column; gap: 0.15rem; }
    .report-title { font-size: 0.95rem; font-weight: 500; color: #1a1a1a; text-decoration: none; }
    .report-title:hover { color: #0066cc; }
    .report-meta { font-size: 0.78rem; color: #999; }
    .report-right { display: flex; align-items: center; gap: 0.6rem; flex-shrink: 0; }
    .report-author { font-size: 0.75rem; background: #eef2ff; color: #4f46e5; padding: 0.2rem 0.6rem; border-radius: 99px; white-space: nowrap; }
    .delete-btn { background: none; border: none; color: #ccc; cursor: pointer; font-size: 0.85rem; padding: 0.2rem 0.4rem; border-radius: 4px; transition: color 0.15s, background 0.15s; }
    .delete-btn:hover { color: #ef4444; background: #fee2e2; }
    .empty { text-align: center; color: #aaa; padding: 3rem; }
    .no-results { text-align: center; color: #aaa; padding: 2rem; display: none; }
    .modal-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.4); z-index: 100; align-items: center; justify-content: center; }
    .modal-overlay.open { display: flex; }
    .modal { background: #fff; border-radius: 12px; padding: 1.5rem; width: 360px; box-shadow: 0 8px 32px rgba(0,0,0,0.15); }
    .modal h3 { font-size: 1rem; margin-bottom: 0.75rem; color: #111; }
    .modal p { font-size: 0.85rem; color: #666; margin-bottom: 1rem; }
    .modal input { width: 100%; border: 1.5px solid #d1d5db; border-radius: 6px; padding: 0.5rem 0.75rem; font-size: 0.875rem; margin-bottom: 1rem; outline: none; }
    .modal input:focus { border-color: #4f46e5; }
    .modal-actions { display: flex; gap: 0.5rem; justify-content: flex-end; }
    .btn { padding: 0.45rem 1rem; border-radius: 6px; font-size: 0.875rem; cursor: pointer; border: none; }
    .btn-cancel { background: #f3f4f6; color: #555; }
    .btn-delete { background: #ef4444; color: #fff; }
    .btn-delete:disabled { opacity: 0.5; cursor: not-allowed; }
  </style>
</head>
<body>
  <h1>📋 ${escapeHtml(team.name)} Wiki</h1>
  <p class="subtitle">共 ${reports.length} 份 report</p>

  ${authors.length > 1 ? `<div class="filter-section">
    <div class="filter-label">成員</div>
    <div class="filters" id="author-filters">
      <button class="filter-btn all-btn active" data-author="all">全部成員 <span class="count">${reports.length}</span></button>
      ${authorButtons}
    </div>
  </div>` : ''}

  ${projects.length > 1 ? `<div class="filter-section">
    <div class="filter-label">專案</div>
    <div class="filters" id="project-filters">
      <button class="filter-btn all-btn active" data-project="all">全部專案</button>
      ${projectButtons}
    </div>
  </div>` : ''}

  <ul class="report-list" id="report-list">${reportItems}</ul>
  <p class="no-results" id="no-results">此過濾條件下沒有 report</p>

  <div class="modal-overlay" id="delete-modal">
    <div class="modal">
      <h3>確認刪除</h3>
      <p>請輸入 Team API Key 以確認刪除：</p>
      <input type="password" id="delete-key-input" placeholder="Team API Key" />
      <div class="modal-actions">
        <button class="btn btn-cancel" id="modal-cancel">取消</button>
        <button class="btn btn-delete" id="modal-confirm">刪除</button>
      </div>
    </div>
  </div>

  <script>
    // Filter logic
    let activeAuthor = 'all';
    let activeProject = 'all';

    function applyFilters() {
      const items = document.querySelectorAll('.report-item');
      let visible = 0;
      items.forEach(item => {
        const authorMatch = activeAuthor === 'all' || item.dataset.author === activeAuthor;
        const projectMatch = activeProject === 'all' || item.dataset.project === activeProject;
        const show = authorMatch && projectMatch;
        item.classList.toggle('hidden', !show);
        if (show) visible++;
      });
      document.getElementById('no-results').style.display = visible === 0 ? 'block' : 'none';
    }

    document.getElementById('author-filters')?.addEventListener('click', e => {
      const btn = e.target.closest('.filter-btn');
      if (!btn) return;
      activeAuthor = btn.dataset.author;
      document.querySelectorAll('#author-filters .filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      applyFilters();
    });

    document.getElementById('project-filters')?.addEventListener('click', e => {
      const btn = e.target.closest('.filter-btn');
      if (!btn) return;
      activeProject = btn.dataset.project;
      document.querySelectorAll('#project-filters .filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      applyFilters();
    });

    // Delete logic
    let pendingDeleteUrl = null;
    const modal = document.getElementById('delete-modal');
    const keyInput = document.getElementById('delete-key-input');
    const confirmBtn = document.getElementById('modal-confirm');

    document.getElementById('report-list').addEventListener('click', e => {
      const btn = e.target.closest('.delete-btn');
      if (!btn) return;
      pendingDeleteUrl = btn.dataset.url;
      keyInput.value = '';
      modal.classList.add('open');
      keyInput.focus();
    });

    document.getElementById('modal-cancel').addEventListener('click', () => {
      modal.classList.remove('open');
      pendingDeleteUrl = null;
    });

    confirmBtn.addEventListener('click', async () => {
      if (!pendingDeleteUrl || !keyInput.value) return;
      confirmBtn.disabled = true;
      try {
        const res = await fetch('/api/delete', {
          method: 'DELETE',
          headers: {
            'Authorization': 'Bearer ' + keyInput.value,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ url: pendingDeleteUrl }),
        });
        if (res.ok) {
          const item = document.querySelector('[data-url="' + pendingDeleteUrl + '"]')?.closest('.report-item');
          item?.remove();
          modal.classList.remove('open');
          pendingDeleteUrl = null;
        } else {
          alert('刪除失敗：' + (await res.text()));
        }
      } catch {
        alert('網路錯誤，請重試');
      }
      confirmBtn.disabled = false;
    });
  </script>
</body>
</html>`;

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
```

#### `src/handlers/report.ts`
```typescript
import { Env } from '../index';

export async function handleReport(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const r2Key = url.pathname.slice(1);

  const object = await env.REPORTS_R2.get(r2Key);
  if (!object) return new Response('Report not found', { status: 404 });

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('Cache-Control', 'public, max-age=3600');

  return new Response(object.body, { headers });
}
```

#### `.gitignore`
```
node_modules/
dist/
.wrangler/
```

### Step 3：建立 Cloudflare 資源

```bash
cd ~/team-wiki-worker
npm install
npx wrangler r2 bucket create <WORKER_NAME>-reports
npx wrangler kv namespace create REPORTS_KV
```

將 KV id 填入 `wrangler.jsonc` 的 `<KV_ID>`。

### Step 4：設定 API Key 並部署

為每個 team 產生並設定 API Key：

```bash
# 產生 key（每個 team 各一把）
openssl rand -hex 32   # 複製為 TEAM_A_API_KEY
openssl rand -hex 32   # 複製為 TEAM_B_API_KEY
openssl rand -hex 32   # 複製為 TEAM_C_API_KEY

# 設定 secret
echo "<TEAM_A_KEY>" | npx wrangler secret put TEAM_A_API_KEY
echo "<TEAM_B_KEY>" | npx wrangler secret put TEAM_B_API_KEY
echo "<TEAM_C_KEY>" | npx wrangler secret put TEAM_C_API_KEY

npx wrangler deploy
```

### Step 5：綁定自訂網域與 Zero Trust

在 Cloudflare Dashboard 完成：

1. **Workers → `<WORKER_NAME>` → Settings → Domains & Routes**
   → Add Custom Domain → 輸入 `<自訂網域>`

2. **Zero Trust → Access → Applications → Add an Application**
   → Self-hosted → Domain: `<自訂網域>`
   → 設定 Policy（例如允許公司 email 網域）

3. **將 `/api` 路徑設為 Bypass（讓 API 呼叫不需 Zero Trust 認證）：**
   → Zero Trust → Access → Applications → Add an Application → Self-hosted
   → Application name: `<WORKER_NAME>-api`
   → Domain: `<自訂網域>`，Path: `/api`
   → 新增 Policy：Action: **Bypass** → Include: Everyone

### Step 6：給管理員設定說明卡產生

部署完成後，為每個 team 產生一張設定說明卡，讓管理員分發給成員：

---
**Team A 成員設定說明**
```bash
# 在專案根目錄建立 .env 檔，填入以下內容

TEAM_WIKI_URL=https://wiki.example.com
TEAM_WIKI_API_KEY=<TEAM_A_KEY>
TEAM_WIKI_AUTHOR=你的英文名字（例如 alice）
TEAM_WIKI_TEAM=team-a
```
---

### Step 7：完成提示

```
✅ Team Wiki 設定完成！

📋 Team A 首頁：https://<自訂網域>/team-a/
📋 Team B 首頁：https://<自訂網域>/team-b/
📋 Team C 首頁：https://<自訂網域>/team-c/
🔒 Zero Trust 保護：已啟用（/api/* 已設為 Bypass）

請將各 team 的設定說明卡分發給對應成員。
```

---

## [成員設定流程] 已有 URL 和 API Key

管理員已給你一張設定說明卡，在**專案根目錄**建立 `.env` 檔，填入以下內容：

```bash
TEAM_WIKI_URL=https://wiki.example.com
TEAM_WIKI_API_KEY=<team-api-key>
TEAM_WIKI_AUTHOR=你的英文名字
TEAM_WIKI_TEAM=<team-id>
```

確認 `.env` 已加入 `.gitignore`（避免 API Key 被 commit）：
```bash
echo ".env" >> .gitignore
```

重新啟動 Claude Code 後即可使用。

---

## [上傳流程] 日常使用

### Step 1：確認資訊

若使用者未提供，依序確認：

1. **HTML 檔案路徑**（必填）
2. **專案名稱**（必填）— 預設用當前目錄名稱：
   ```bash
   basename $PWD
   ```
3. **Report 標題**（選填）— 從 HTML `<title>` tag 讀取：
   ```bash
   grep -o '<title>[^<]*</title>' <file> | sed 's/<[^>]*>//g' | head -1
   ```
   若讀不到，用「`<project>-<YYYY-MM-DD>`」
4. **日期**（選填）— 格式 `YYYY-MM-DD`，省略則用今天。

### Step 2：推薦 Tags

上傳前，先讀取 HTML 內容，根據以下清單推薦 1 個**類型** tag + 1-2 個**環節** tag，讓使用者確認或修改後再上傳。

**類型（這份報告是什麼）**
- `研究報告` — 技術調查、工具評估、可行性分析
- `實驗結果` — A/B test、模型比較、prompt 測試結果
- `成果報告` — 某個優化階段的最終產出與結論
- `週報` — 定期進度更新

**環節（屬於哪個流程）**
- `影片生成` — AI 影片生成相關（Sora、Runway、Kling 等）
- `影片剪輯` — 自動剪輯、字幕、後製流程優化
- `腳本生成` — AI 自動產生影片腳本
- `行銷文案` — 廣告文案、社群貼文自動化
- `受眾分析` — 受眾定向、數據分析
- `流程自動化` — 跨平台串接、自動化 pipeline

使用者也可以自由輸入清單以外的 tag。

### Step 3：上傳

```bash
curl -X POST ${TEAM_WIKI_URL}/api/publish \
  -H "Authorization: Bearer ${TEAM_WIKI_API_KEY}" \
  -F "file=@<filepath>" \
  -F "team=${TEAM_WIKI_TEAM}" \
  -F "author=${TEAM_WIKI_AUTHOR}" \
  -F "project=<project>" \
  -F "title=<title>" \
  -F "tags=<tag1,tag2>" \
  -F "date=<YYYY-MM-DD HH:mm>"
```

### Step 3：回報結果

```
✅ Report 已發布！
🔗 直接連結：${TEAM_WIKI_URL}/<team>/<author>/<project>/<filename>
📋 Team 書籤：${TEAM_WIKI_URL}/<team>/
```

---

## 管理員新增/修改 Team

編輯 `wrangler.jsonc` 的 `vars` 區塊，新增或修改 team 設定，然後重新部署：

```bash
# 若有新 team，先設定 API Key
echo "<NEW_KEY>" | npx wrangler secret put TEAM_D_API_KEY

# 更新 vars 後重新部署
npx wrangler deploy
```

成員名單是 dynamic 的，有人上傳 report 後就會自動出現在過濾器，不需要預先設定。
