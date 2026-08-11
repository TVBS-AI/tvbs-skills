---
name: my-wiki
description: 個人 HTML report 書籤 wiki，由 Cloudflare Worker + R2 + KV 驅動。第一次使用時自動 setup（產生程式碼並部署），之後可在任何專案上傳 HTML report 並自動更新書籤首頁。當使用者提到「上傳 report」、「發布 report」、「publish」、「my wiki」時觸發。
---

# My Wiki — Personal Report Bookmark

這個 skill 讓你在任何地方用一句話把 HTML report 上傳到自己的 Cloudflare Worker wiki，並自動維護書籤首頁。

**架構：** Cloudflare Worker + R2（存 HTML 檔案）+ KV（書籤清單）+ 自訂網域 + Zero Trust

---

## 第一步：偵測狀態

```bash
echo "WORKER_URL=${MY_WIKI_WORKER_URL:-NOT_SET}"
```

- 輸出 `NOT_SET` → 執行 **[Setup 流程]**
- 有值 → 執行 **[上傳流程]**

---

## [Setup 流程] 第一次使用

### Prerequisites 確認

```bash
npx wrangler whoami 2>&1 | head -5
```

若未登入，請使用者先執行：
```
! npx wrangler login
```

### Step 1：詢問設定（每次一個問題）

1. **Worker 名稱**（必填）— 例如 `alice-wiki`，只用英數字和連字號
2. **你的名字**（必填）— 顯示在書籤首頁標題，例如 `Alice`
3. **自訂網域**（必填）— 例如 `wiki.example.com`，必須是你在 Cloudflare 管理的網域

### Step 2：產生 Worker 專案

在 `~/my-wiki-worker` 目錄（或使用者指定的位置）產生以下檔案：

#### `package.json`
```json
{
  "name": "my-wiki-worker",
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
（`<WORKER_NAME>`、`<CUSTOM_DOMAIN>`、`<KV_ID>` 替換為實際值）
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
  ]
}
```

> `<CUSTOM_DOMAIN>` 格式為 `wiki.example.com`（不含 `https://`，不含 `/*`）。該網域必須已加入你的 Cloudflare 帳號。`wrangler deploy` 時會自動建立 DNS 記錄並綁定，不需要手動去 Dashboard 設定。

#### `src/index.ts`
```typescript
import { handlePublish } from './handlers/publish';
import { handleIndex } from './handlers/index-page';
import { handleReport } from './handlers/report';

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const method = request.method;

    if (pathname === '/api/publish' && method === 'POST') {
      return handlePublish(request, env);
    }

    if (pathname === '/' && method === 'GET') {
      return handleIndex(request, env);
    }

    if (method === 'GET' && pathname.match(/^\/[^/]+\/[^/]+\.html?$/)) {
      return handleReport(request, env);
    }

    return new Response('Not Found', { status: 404 });
  },
};

export interface Env {
  REPORTS_KV: KVNamespace;
  REPORTS_R2: R2Bucket;
  API_KEY: string;
}
```

#### `src/handlers/publish.ts`
```typescript
import { Env } from '../index';

export interface ReportEntry {
  project: string;
  filename: string;
  title: string;
  url: string;
  createdAt: string;
}

export async function handlePublish(request: Request, env: Env): Promise<Response> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || authHeader !== `Bearer ${env.API_KEY}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return new Response('Invalid multipart form data', { status: 400 });
  }

  const file = formData.get('file') as File | null;
  const project = formData.get('project') as string | null;
  const title = formData.get('title') as string | null;
  const dateParam = formData.get('date') as string | null;

  if (!file || !project) {
    return new Response('Missing required fields: file, project', { status: 400 });
  }

  const filename = file.name;
  if (!filename.endsWith('.html') && !filename.endsWith('.htm')) {
    return new Response('Only HTML files are allowed', { status: 400 });
  }

  const safeFilename = filename.replace(/[^a-zA-Z0-9-_.]/g, '-');
  const safeProject = project.replace(/[^a-zA-Z0-9-_]/g, '-').toLowerCase();
  const r2Key = `${safeProject}/${safeFilename}`;

  const htmlContent = await file.arrayBuffer();
  await env.REPORTS_R2.put(r2Key, htmlContent, {
    httpMetadata: { contentType: 'text/html; charset=utf-8' },
  });

  const reportTitle = title || safeFilename.replace(/\.html?$/, '');
  const reportUrl = `/${safeProject}/${safeFilename}`;
  const isValidDate = dateParam !== null && /^\d{4}-\d{2}-\d{2}$/.test(dateParam);
  const createdAt = isValidDate ? dateParam : new Date().toISOString().split('T')[0];

  const existingJson = (await env.REPORTS_KV.get('reports')) ?? '[]';
  const reports: ReportEntry[] = JSON.parse(existingJson);

  const newEntry: ReportEntry = {
    project: safeProject,
    filename: safeFilename,
    title: reportTitle,
    url: reportUrl,
    createdAt,
  };

  const updatedReports = [newEntry, ...reports.filter((r) => r.url !== reportUrl)];
  await env.REPORTS_KV.put('reports', JSON.stringify(updatedReports));

  const workerUrl = new URL(request.url).origin;

  return new Response(
    JSON.stringify({
      success: true,
      url: `${workerUrl}${reportUrl}`,
      indexUrl: `${workerUrl}/`,
    }),
    {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }
  );
}
```

#### `src/handlers/index-page.ts`
（`<YOUR_NAME>` 替換為使用者的名字）
```typescript
import { Env } from '../index';
import { ReportEntry } from './publish';

export async function handleIndex(_request: Request, env: Env): Promise<Response> {
  const reportsJson = (await env.REPORTS_KV.get('reports')) ?? '[]';
  const reports: ReportEntry[] = JSON.parse(reportsJson);

  const projects = [...new Set(reports.map((r) => r.project))];

  const filterButtons =
    projects.length > 1
      ? `<div class="filters">
  <button class="filter-btn active" data-filter="all">全部 <span class="count">${reports.length}</span></button>
  ${projects
    .map((p) => {
      const count = reports.filter((r) => r.project === p).length;
      return `<button class="filter-btn" data-filter="${escapeHtml(p)}">${escapeHtml(p)} <span class="count">${count}</span></button>`;
    })
    .join('\n  ')}
</div>`
      : '';

  const reportItems =
    reports.length === 0
      ? '<p class="empty">No reports yet. Use the my-wiki skill to publish one!</p>'
      : reports
          .map(
            (r) => `
      <li class="report-item" data-project="${escapeHtml(r.project)}">
        <div class="report-info">
          <a class="report-title" href="${escapeHtml(r.url)}" target="_blank">${escapeHtml(r.title)}</a>
          <span class="report-meta">${escapeHtml(r.createdAt)} · ${escapeHtml(r.filename)}</span>
        </div>
        <span class="report-project">${escapeHtml(r.project)}</span>
      </li>`
          )
          .join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><YOUR_NAME>'s Reports</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 2rem; }
    h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #111; }
    .subtitle { color: #666; margin-bottom: 1.5rem; font-size: 0.9rem; }
    .filters { display: flex; flex-wrap: wrap; gap: 0.5rem; margin-bottom: 1.5rem; }
    .filter-btn { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.85rem; border-radius: 99px; border: 1.5px solid #d1d5db; background: #fff; color: #555; font-size: 0.82rem; cursor: pointer; transition: all 0.15s; }
    .filter-btn:hover { border-color: #4f46e5; color: #4f46e5; }
    .filter-btn.active { background: #4f46e5; border-color: #4f46e5; color: #fff; }
    .filter-btn .count { font-size: 0.75rem; opacity: 0.8; }
    .report-list { list-style: none; display: flex; flex-direction: column; gap: 0.75rem; }
    .report-item { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; padding: 1rem 1.25rem; display: flex; align-items: center; justify-content: space-between; transition: box-shadow 0.15s; }
    .report-item:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    .report-item.hidden { display: none; }
    .report-info { display: flex; flex-direction: column; gap: 0.2rem; }
    .report-title { font-size: 1rem; font-weight: 500; color: #1a1a1a; text-decoration: none; }
    .report-title:hover { color: #0066cc; }
    .report-meta { font-size: 0.8rem; color: #999; }
    .report-project { font-size: 0.75rem; background: #eef2ff; color: #4f46e5; padding: 0.2rem 0.6rem; border-radius: 99px; white-space: nowrap; }
    .empty { text-align: center; color: #aaa; padding: 3rem; }
    .no-results { text-align: center; color: #aaa; padding: 2rem; display: none; }
  </style>
</head>
<body>
  <h1>📋 <YOUR_NAME>'s Reports</h1>
  <p class="subtitle">Maintained automatically by Claude Code</p>
  ${filterButtons}
  <ul class="report-list" id="report-list">${reportItems}</ul>
  <p class="no-results" id="no-results">No reports in this project</p>
  <script>
    const buttons = document.querySelectorAll('.filter-btn');
    const items = document.querySelectorAll('.report-item');
    const noResults = document.getElementById('no-results');
    buttons.forEach(btn => {
      btn.addEventListener('click', () => {
        const filter = btn.dataset.filter;
        buttons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        let visible = 0;
        items.forEach(item => {
          const match = filter === 'all' || item.dataset.project === filter;
          item.classList.toggle('hidden', !match);
          if (match) visible++;
        });
        noResults.style.display = visible === 0 ? 'block' : 'none';
      });
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

  if (!object) {
    return new Response('Report not found', { status: 404 });
  }

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
cd ~/my-wiki-worker
npm install
npx wrangler r2 bucket create <WORKER_NAME>-reports
npx wrangler kv namespace create REPORTS_KV
```

將 KV id 填入 `wrangler.jsonc` 的 `<KV_ID>`。

### Step 4：產生 API Key 並部署

```bash
openssl rand -hex 32
# 記下產生的 key
echo "<API_KEY>" | npx wrangler secret put API_KEY
npx wrangler deploy
```

> 因為 `workers_dev: false`，部署後會顯示「No deploy targets」是正常的，等綁定自訂網域後才會有 route。

### Step 5：綁定自訂網域

在 Cloudflare Dashboard 完成：

1. **Workers → `<WORKER_NAME>` → Settings → Domains & Routes**
   → Add Custom Domain → 輸入 `<自訂網域>`

2. **Zero Trust → Access → Applications → Add an Application**
   → Self-hosted → Domain: `<自訂網域>`
   → 設定 Policy（例如允許公司 email 網域）

3. **建立 Service Token（給 API 上傳用）：**
   → Zero Trust → Access → Service Auth → Create Service Token
   → 名稱：`my-wiki-publish`
   → 記下 `CF-Access-Client-Id` 和 `CF-Access-Client-Secret`

4. **把 Service Token 加入 Application Policy：**
   → 該 Application → Edit → Policies → 新增一條 Policy
   → Action: **Service Auth**（不是 Allow）
   → Include: Service Token → `my-wiki-publish`

### Step 6：設定環境變數

將以下內容加到 `~/.zshenv`（**注意是 `.zshenv` 而非 `.zshrc`**，才能讓 Claude Code 讀到）：

```bash
export MY_WIKI_WORKER_URL="https://<自訂網域>"
export MY_WIKI_API_KEY="<API_KEY>"
export MY_WIKI_CF_CLIENT_ID="<CF-Access-Client-Id>"
export MY_WIKI_CF_CLIENT_SECRET="<CF-Access-Client-Secret>"
```

重新啟動 Claude Code 讓設定生效。

### Step 7：完成提示

```
✅ Wiki 設定完成！

📋 書籤首頁：https://<自訂網域>/
🔒 Zero Trust 保護：已啟用
🔑 Service Token：已設定，可從任何地方上傳

下次在任何專案說「幫我上傳 report 到 wiki」即可使用！
```

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
4. **日期**（選填）— 格式 `YYYY-MM-DD`，省略則用今天。上傳歷史 report 時使用。

### Step 2：上傳

```bash
curl -X POST ${MY_WIKI_WORKER_URL}/api/publish \
  -H "Authorization: Bearer ${MY_WIKI_API_KEY}" \
  -H "CF-Access-Client-Id: ${MY_WIKI_CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${MY_WIKI_CF_CLIENT_SECRET}" \
  -F "file=@<filepath>" \
  -F "project=<project>" \
  -F "title=<title>" \
  -F "date=<YYYY-MM-DD>"
```

### Step 3：回報結果

```
✅ Report 已發布！
🔗 直接連結：${MY_WIKI_WORKER_URL}/<project>/<filename>
📋 書籤清單：${MY_WIKI_WORKER_URL}/
```
