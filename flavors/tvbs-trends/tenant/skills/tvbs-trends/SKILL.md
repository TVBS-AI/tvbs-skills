---
name: tvbs-trends
description: >
  查詢 TVBS Google Trends 趨勢系統，取得即時飆升關鍵字、新聞機會偵測
  （獨家搶快／緊急跟進）、關鍵字聲量走勢與歷史快照。當使用者詢問「現在有什麼
  熱門話題」「有什麼新聞該搶快或跟進」「某關鍵字的聲量趨勢」「今天某主題在紅
  什麼」「我們漏了什麼題」時使用。
---

# TVBS Trends

查詢台灣 Google Trends 飆升趨勢，並自動比對 TVBS 新聞資料庫，找出值得報導的新聞機會。

## 認證（自動管理，無需操作）

`TVBS_TRENDS_KEY` 是 Hub 管理的 egress stub。**請勿印出、記錄或傳遞此值。**
CLI 讀取它，Hub egress proxy 在對 `trends.tvbs.ai` 的請求中自動替換成真實 key。

## 使用 CLI

```bash
# 找新聞機會（最常用）
tvbs-trends opportunities --window-hours 24

# 找緊急跟進題材
tvbs-trends opportunities --window-hours 4 | \
  jq '.data[] | select(.trend_classification == "Urgent Follow-up")'

# 快速看最新熱門（可接受一小時內舊資料，速度快）
tvbs-trends latest --window-hours 24

# 關鍵字走勢（中文直接帶）
tvbs-trends timeline --keyword 颱風 --window-hours 24

# 給新聞部的格式化通知
tvbs-trends digest --format plain --pretty

# 歷史回溯：昨天下午三點當時在紅什麼
tvbs-trends snapshot --before "2026-08-01T15:00:00+08:00"
```

## 選對指令（成本差很大）

| 使用者需求 | 指令 | 速度 |
|-----------|------|------|
| 有什麼該搶快／該跟進的新聞機會？ | `opportunities` | 慢（分析） |
| 格式化通知，可直接發送 | `digest` | 慢（分析） |
| 現在最熱門關鍵字（即時） | `trending` | 慢（爬蟲） |
| 熱門關鍵字，可接受一小時前資料 | `latest` | **快（快照）** |
| 某關鍵字走勢 | `timeline` | **快（快照）** |
| 某時間點當時的熱門趨勢 | `snapshot` | **快（快照）** |

**預設優先快照類**：沒有強調「此刻最新」時，用 `latest`（快、不消耗爬蟲配額）。

## 共用參數

- `--geo`：地區代碼，預設 `TW`
- `--window-hours`：只接受 `4`、`24`、`48`，預設 `24`
- `--num-news`：每趨勢附帶幾則新聞，1–30，預設 5

## 回應信封

```json
{
  "meta": {
    "source": "snapshot",
    "fetched_at": "...",
    "staleness_seconds": 2492,
    "warnings": []
  },
  "data": { ... }
}
```

回覆使用者前先看 `meta`：`staleness_seconds` 決定是否提醒資料新舊，`warnings` 決定是否加註可信度。

## 錯誤處理

- `TVBS_TRENDS_KEY` 未設定 → 聯絡 Hub 管理員確認 managed secret 已為此 tenant 建立
- `401` → key 無效
- `422` → 參數不合法（`window_hours` 必須是 4/24/48）
- `500` → 伺服器錯誤，稍後重試
