---
name: trends-query
description: 查詢 TVBS Google Trends 趨勢系統，取得即時飆升關鍵字、新聞機會偵測（獨家搶快／緊急跟進）、關鍵字聲量走勢與歷史快照。當使用者詢問「現在有什麼熱門話題」「有什麼新聞該搶快或跟進」「某關鍵字／藝人的聲量趨勢」「今天某主題（娛樂／政治…）在紅什麼」「我們（TVBS）漏了什麼題」時使用。涵蓋新聞部、網路文章編輯、娛樂部、公關部等情境。首選用 npm CLI（npx @tvbs-ai/tvbs-trends）呼叫。
---

# TVBS Trends

查詢台灣 Google Trends 飆升趨勢，並自動比對 TVBS 新聞資料庫，找出值得報導的新聞機會。

## 首選：用 CLI（`npx @tvbs-ai/tvbs-trends`）

若你的環境能執行 shell 指令，**優先用 CLI** —— 單次呼叫就拿到結果、不必維持連線、輸出是可直接解析的 JSON，比 MCP 省 context。

```bash
export TVBS_TRENDS_API_KEY=<你的-key>   # 向 AI 部門索取，各團隊一把
npx -y @tvbs-ai/tvbs-trends opportunities --geo TW --window-hours 24
```

- 預設輸出是 API 的原始 **Envelope JSON**（`{ meta, data }`，見下方「回應信封」），直接解析即可。
- 加 `--pretty` 給人看的表格；查詢一律唯讀。
- 缺 key 或 key 錯 → stderr 顯示錯誤並以非零 exit code 結束。
- `--api-key <key>` 可覆寫 env；`--base-url <url>` 可指向其他環境（預設 `https://trends.tvbs.ai`）。

### 認證

CLI 從環境變數 `TVBS_TRENDS_API_KEY` 讀 key（或用 `--api-key` 帶）。**key 向 AI 部門索取**，各團隊一把（newsroom / editor / pr），呼叫會依 key 記錄來源團隊。勿把 key 寫死在公開程式碼或提交進 git。

### 選對指令（最重要）

先判斷需求屬於哪一類再選指令。**成本差很大**：`live/*` 爬蟲類慢（數秒、有頻率限制），快照類（`latest`/`snapshot`/`timeline`）快（毫秒、讀資料庫）。

| 使用者想要 | CLI 指令 | 類型 |
|-----------|---------|------|
| 有什麼該搶快／該跟進的新聞機會？我們漏了什麼？ | `opportunities` | 分析（最慢） |
| 一份給新聞部、排版好可直接發送的通知 | `digest` | 分析（最慢） |
| 現在最熱門的飆升關鍵字（此刻最新） | `trending` | 爬蟲（慢） |
| 熱門關鍵字，但可接受最多一小時前的資料（要快） | `latest` | 快照（快） |
| 某關鍵字／人物的聲量走勢（過去這幾天趨勢如何） | `timeline` | 快照（快） |
| 某關鍵字的搜尋熱度時序（此刻爬新的） | `interest` | 爬蟲（慢） |
| 過去某個時間點當時的熱門趨勢（事後回溯） | `snapshot --before <時間>` | 快照（快） |

**預設優先快照類**：若使用者沒強調「此刻最新」，優先用 `latest`（快、不消耗爬蟲配額）。只有明確需要「現在這一秒」才用 `trending`／`interest`。

任何指令加 `--help` 看完整參數：`npx -y @tvbs-ai/tvbs-trends opportunities --help`。

### 常用指令範例

```bash
# 找新聞機會（最常用）；篩緊急跟進
npx -y @tvbs-ai/tvbs-trends opportunities --window-hours 24 --num-trends 10 \
  | jq '.data[] | select(.trend_classification == "Urgent Follow-up") | .keyword'

# 快速看最新熱門（可接受一小時內舊資料）
npx -y @tvbs-ai/tvbs-trends latest --geo TW --window-hours 4

# 某關鍵字走勢（中文直接帶即可，CLI 會處理編碼）
npx -y @tvbs-ai/tvbs-trends timeline --keyword 颱風 --window-hours 24

# 給新聞部的通知，排版好的純文字
npx -y @tvbs-ai/tvbs-trends digest --window-hours 24 --format plain --pretty

# 歷史回溯：昨天下午三點當時在紅什麼
npx -y @tvbs-ai/tvbs-trends snapshot --before "2026-07-01T15:00:00+08:00" --window-hours 24
```

### 共用參數

- `--geo`：地區代碼，預設 `TW`。其他如 `US`、`JP`。
- `--window-hours`：趨勢窗口，**只接受 `4`、`24`、`48`**（其他值 CLI 會直接報錯）。預設 `24`。`4`＝最新／即時、`24`＝今天、`48`＝這兩天。
- `--num-news`：每個趨勢附帶幾則新聞，1–30，預設 5。

### 各指令專屬參數

- **`opportunities`**：`--lookback-hours`（1–168，預設 24，回看多久算「已見過」）、`--num-trends`（預設 10）。
- **`digest`**：`--format`（`markdown`／`plain`／`json`，預設 markdown）、`--include-all`（預設只列有新聞價值的；帶此旗標全列）、`--max-entries`、`--max-news`（每來源幾則，預設 3）。
- **`interest`**：`--keywords`（必填，逗號分隔，如 `颱風,地震`）、`--timeframe`（預設 `now 1-H`，如 `now 7-d`）。
- **`timeline`**：`--keyword`（必填）、`--since`、`--until`（含時區，如 `2026-07-01T00:00:00+08:00`）。
- **`snapshot`**：`--before`（必填，含時區的 ISO 時間）。

## 備援：MCP 與 REST（環境不能跑 CLI 時）

CLI 是首選。若你的 runtime **不能執行 shell / npx**，改用下列其一；三者資料與語意完全一致。

### MCP（原生連接）

端點 `https://trends.tvbs.ai/mcp/`（streamable-http，帶同一把 API key）。**注意結尾斜線** —— 直接用 `/mcp/`；`/mcp`（無斜線）會 307 轉址。健康檢查 `/mcp/health` 免認證。工具命名對 AI 友善：`find_news_opportunities`、`get_news_digest`、`get_latest_snapshot`、`get_trending_now`、`scan_topic_trends`、`check_topic_momentum` 等。能接 MCP 時它比純 REST 好（工具描述內建中文引導）。

### REST（純 HTTP）

- Base URL：`https://trends.tvbs.ai`，一律用 **`/api/v2/`**（v1 已 deprecated）。
- 認證：header `X-API-Key: <key>`（或 `Authorization: Bearer <key>`）。
- CLI 指令對應的端點：`opportunities`→`/api/v2/trends/opportunities`、`digest`→`/api/v2/trends/digest`、`trending`→`/api/v2/trends/live/trending`、`latest`→`/api/v2/trends/snapshots/latest`、`timeline`→`/api/v2/trends/snapshots/timeline`、`interest`→`/api/v2/trends/live/interest`、`snapshot`→`/api/v2/trends/snapshots`。

```bash
curl -H "X-API-Key: <KEY>" \
  "https://trends.tvbs.ai/api/v2/trends/opportunities?geo=TW&window_hours=24"

# 中文參數必須 URL 編碼（否則回 Invalid HTTP request）
curl -H "X-API-Key: <KEY>" -G \
  "https://trends.tvbs.ai/api/v2/trends/snapshots/timeline" \
  --data-urlencode "keyword=颱風" --data-urlencode "window_hours=24"
```

> REST 直接組 URL 時，含中文的 `keyword`／`keywords` 必須編碼（curl 用 `-G --data-urlencode`，程式用 `params`／`URLSearchParams`）。用 CLI 則不必煩惱，直接帶中文即可。

## 回應信封

CLI 預設輸出、MCP 與 REST 回應都是同一種信封：

```json
{
  "meta": {
    "source": "snapshot",              // "live"｜"snapshot"｜"hybrid"：資料來源
    "fetched_at": "2026-07-20T16:34:24Z",
    "snapshot_time": "2026-07-20T15:52:51Z",  // 快照類才有，資料實際時間
    "staleness_seconds": 2492,         // 資料多舊（秒）；live 為 0
    "is_new_reliable": null,           // opportunities 專用：isNew 是否可信
    "warnings": []                     // 非致命提醒，若有內容要轉達使用者
  },
  "data": { ... }                      // 實際資料
}
```

**使用原則**：回覆使用者前先看 `meta` —— `staleness_seconds` 決定要不要提醒資料新舊，`warnings` 與 `is_new_reliable` 決定要不要加註可信度。

### ⚠️ `data` 的型別依指令而不同（最容易解析錯的地方）

| 指令 | `data` 型別 | 取每筆趨勢 |
|------|-----------|-----------|
| `opportunities`、`trending` | **陣列** | `data[i]` |
| `latest`、`snapshot` | **物件**，趨勢在 `data.trends` | `data.trends[i]` |
| `timeline` | **物件**，序列在 `data.points` | `data.points[i]` |
| `digest` | **物件**（`summary`／`entries`／`text`） | 見下方 digest 段 |

### 趨勢項目核心欄位

- `keyword`：關鍵字
- `volume`：搜尋量
- `volume_growth_pct`：成長率（%）
- `trend_keywords`：相關關鍵字陣列
- `trend_classification`：機會分類（僅 `opportunities` 有）
- `tvbs_similar_news`：TVBS 已有的相似新聞（空陣列＝我們沒寫）
- `news`：Google 上的相關新聞
- `isNew`：是否為新出現的趨勢（受 `is_new_reliable` 影響）

### `opportunities` 的分類（`trend_classification`）

- `Exclusive Opportunity`（獨家搶快機會）：飆升 300%+、全網幾乎無報導，**且 TVBS 也還沒寫** → 真正可搶的獨家。
- `Urgent Follow-up`（緊急跟進）：Google 已有 3 篇以上報導但 TVBS 尚未寫 → 可能漏題了。
- `null`：不屬於上述機會。

**重要**：讀 `meta.is_new_reliable`。若為 `false`，代表查無足夠歷史快照可比對，「是否為新趨勢」不可信，回覆使用者時要據實說明。

### `digest` 的 `data`

- `summary`：總覽統計（`total`、`exclusive_count`、`follow_up_count`、`tvbs_missing_count`）——做摘要行直接用。
- `entries`：每筆帶 `priority`（數字越小越急，**已排序**）、`action_type`（exclusive／follow_up）、`signal`（一句話說「為何值得注意」）、`tvbs_missing`。
- `text`：`--format markdown/plain` 時是排版好、可直接發送的文字；`--format json` 時為 `null`。

**用法**：要自己組通知就用 `--format json`（拿 `entries` 自由呈現）；要現成文字直接發就用 `--format markdown`／`plain`。

## 常見情境對應

- 「現在有什麼該搶快的獨家？」→ `opportunities --window-hours 4`，篩 `trend_classification == "Exclusive Opportunity"`
- 「有哪些題大家在報我們漏了？」→ `opportunities`，篩 `"Urgent Follow-up"`
- 「今天最熱的話題？」→ `latest --window-hours 24`
- 「『某藝人』最近聲量有變化嗎？」→ `timeline --keyword 某藝人`
- 「昨天下午三點當時在紅什麼？」→ `snapshot --before <昨天15:00含時區>`

## 錯誤處理

- **CLI**：缺 key／key 錯 → 401 訊息 + 非零 exit code；`--window-hours` 填 4/24/48 以外的值 → CLI 端直接報錯（不發請求）。
- **REST**：`401` key 無效或缺少；`422` 參數不合法（最常見是 `window_hours` 非 4/24/48）；`500` 伺服器錯誤，稍後重試。

## 保持最新（未來升級時）

此服務會持續演進。**當行為與本文件不符、或需要確認最新規格時**：

- CLI 版本與指令：`npx -y @tvbs-ai/tvbs-trends --help`；套件資訊 `npm view @tvbs-ai/tvbs-trends`。
- API 權威規格（免認證、公開可讀）：`curl -s "https://trends.tvbs.ai/openapi.json"`，與線上部署永遠一致，含所有端點、參數、預設值、enum、回傳結構。互動式文件 `https://trends.tvbs.ai/docs`。

**升級判斷原則**：若 `/openapi.json` 或 CLI `--help` 出現本文件沒有的指令／參數、或 `window_hours` 的允許值改變，以它們為準，並提醒使用者本技能文件可能需要更新。
