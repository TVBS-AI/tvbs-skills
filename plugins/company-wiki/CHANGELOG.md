# Changelog

## [0.2.1] - 2026-10-12
### Changed
- 改由公開的 `TVBS-AI/tvbs-skills` 發佈（原本在私有的 `TVBS-AI/agent-skills`），不需要 GitHub org 權限即可安裝；`https://wiki.tvbs.ai/setup` 也改從這裡下載 SKILL.md

## [0.2.0] - 2026-10-12
### Added
- [連結流程]：第一次使用時由 agent 建立連結請求，使用者只要在瀏覽器確認代碼並按「允許」，不用複製 token
- 備案：使用者貼上網頁產生的連結碼時，由 agent 存檔
- skill 也可從 `https://wiki.tvbs.ai/setup` 安裝（不需要 GitHub 權限），內容與本檔同步

### Changed
- token 改存 `~/.config/company-wiki/token`（權限 600），桌面版 app 也讀得到；`COMPANY_WIKI_TOKEN` 環境變數仍優先
- 對使用者的說明改成非技術用語，不再要求編輯 `~/.zshrc` 或重啟 agent
- 401 時清除失效的連結碼並重新連結

## [0.1.0] - 2026-10-07
### Added
- Initial release: TVBS company HTML report wiki at `https://wiki.tvbs.ai`
- 個人 upload token 設定、個人／團隊空間與全公司／團隊／私人可見範圍
- HTML 上傳、tag 推薦、文件清單／內容查詢與刪除流程
- 研究任務或大型任務完成後，主動詢問是否產生 HTML 報告並上傳 company-wiki
