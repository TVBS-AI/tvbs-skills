# 設定、清理與更新

SKILL.md 第 0 節會叫你來讀這份。處理設定、清理或更新的這一輪，不產生頁面。下文的 `am` 代表 `node "${CLAUDE_SKILL_DIR}/scripts/am.mjs"`。

## 設定

- 使用者只說「設定」時：執行 `am config` 顯示目前設定，再讓使用者選。工具能發問時（例如 AskUserQuestion），一次最多問 4 項，先問 `open`、`theme`、`mode`、`style`，選項裡標出目前的值。不能發問時用文字問。
- 使用者用自然語言要求時（「不要再自動開瀏覽器」「預設用深色」），轉成 `am config set <key> <value>`。
- `am config reset [key]` 恢復預設值。

| 設定 | 預設值 | 作用 |
| :--- | :--- | :--- |
| `open` | `on` | 產生後自動用瀏覽器打開 |
| `theme` | `auto` | 預設主題：`auto`（長文用 paper，有圖用 blueprint）、`blueprint`、`shadcn`、`paper`，或自訂主題。稿件裡寫的主題優先 |
| `mode` | `auto` | 預設深淺色：`auto`、`light`、`dark` |
| `style` | `80` | 寫作檢查：`off`、`80`（只警告）、`strict`（不合格就不產生頁面） |
| `scale` | `1` | 頁面文字大小，0.8–1.5，每次 0.05；圖表會跟著放大。讀者也能用工具列的 A− / A+ 調整 |
| `close_after_reply` | `off` | 複製回覆 3 秒後關閉分頁（有「保持開啟」按鈕） |

- 設定存在 `~/.tvbs-html-report/config.json`。`--open`、`--no-open` 只影響這一次。
- `update_check` 和 `colophon` 這兩項在這個版本沒有作用，也不要打開：更新改由 tvbs-skills plugin 提供，頁首署名已經拿掉。
- 不要碰 `voice`：它是影片配音的設定，這個 skill 不做影片。

## 自訂主題

- 在 `~/.tvbs-html-report/themes/` 放 JSON 檔案，一個檔案一個主題，檔名就是主題名稱。格式和顏色變數用 `am help theme` 查。
- `am theme check <名稱>` 會檢查缺少的顏色變數、對比度和外部資源，並產生樣張。
- `am theme add <名稱>` 會連到原作者的網站 answer-me-with-html.com 下載現成主題。只在使用者明確要求某個現成主題時才用，並先告訴使用者會連到這個外部網站。

## 清理

頁面和暫存稿存在 `~/.tvbs-html-report/`。CLI 輸出 `! Cleanup hint` 時，或使用者要求清理時：

1. 先執行 `am clean --dry-run`，告訴使用者會刪掉幾個項目、多少空間。
2. 使用者同意後才執行 `am clean`。預設刪掉 30 天前的頁面和暫存稿；`--days N` 改天數，`--all` 刪掉全部。設定和主題一定會保留。

## 更新

依安裝方式更新：

- Claude Code plugin：執行 `claude plugin update html-report@tvbs-skills`，或請使用者在 `/plugin` → Installed 按 Update now，然後請使用者執行 `/reload-plugins`。
- `npx skills add` 安裝的：執行 `npx -y skills update html-report -y`。

CLI 不會自己檢查新版本。
