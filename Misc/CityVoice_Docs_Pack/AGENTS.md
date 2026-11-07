# AGENTS.md — CityVoice AI Coding Agent Instructions

本檔案對所有參與 CityVoice 的 AI coding agents 有約束力。適用於 ChatGPT、Codex、Claude Code、GitHub Copilot 等工具。**請先讀 `README.md`、再讀 `PRIORITIES.md`，最後讀本檔案；若與官方最新競賽規則衝突，以官方規則為優先並向人類隊長回報。**

## 1. 你的任務

協助 4–5 人隊伍在 2026 臺北秋季程式設計節製作「厝邊聲援 CityVoice」：一個與 TownPass 整合的**語音優先、多語言、可降級、資料可信**的數位平權市政服務助理。

這**不是**自由聊天機器人、翻譯平台、政府授權代理人、正式申請系統或雲端 AI 服務。

預期使用者：臺灣長者、新住民、使用舊手機或數位能力受限的市民。尊重使用者自主選擇語言、輸入方式與是否請人協助。

成功標準：在一支真實 iPhone 上完成一條有可信官方來源的市政任務；最好可加入經實測的離線華語語音及一種非華語語音；即使模型失敗，文字／Basic Mode 也能完成任務。

## 2. 不可違反的規則（Stop Conditions）

一旦任務需要以下任何行為，**停止實作該部分，標示 blocker 並請人類負責人確認**：

1. **執行時使用雲端 LLM API、遠端 LLM server，或把使用者輸入／作品資料送至後端做 LLM 推論。** 開發時可使用雲端 AI 幫助編寫程式，但交付 App 不可這樣做。
2. 使用未審核開源授權、權重授權、付費／商用模組或受競賽資通安全限制的第三方產品（包括規則所列中國大陸廠牌產品）。
3. 把未查證或已過期的據點、時段、資格、電話、地址或政策當成最新正式資訊。
4. 收集、上傳、寫入 log、分享或嵌入 QR 內的證號、密碼、token、自由文字、音訊、逐字稿、聲紋或其他不必要的敏感內容。
5. 宣稱模型支援特定語言、口音、設備或完全離線，而沒有真機證據。
6. 未經人類確認擅自修改官方 TownPass 架構、加入新的重型框架、擴大 MVP 範圍、使用預先開發作品違反尚待確認的競賽規則。
7. 在 GitHub 上覆蓋人類隊友未提交的工作、強制推送共用分支、刪除不相關檔案或提交 secrets。

競賽硬性資訊（來自團隊持有的官方須知／時間表）：11/7–11/8，正式題目以主辦公告為準；所有即時 LLM 推論需在裝置端；成果須符合開源／AGPL 要求；成果發表只能投影實際運作畫面，初選約 2 分鐘、決選約 5 分鐘。**若不確定賽前 PoC 是否可合併入正式作品，不要自行下結論。**

## 3. 證據標準與用語

每個規格、模型、資料和測試結果都要能標示以下狀態之一：

- `VERIFIED`：有來源或可重現的實測輸出、日期、設備／版本。
- `ASSUMPTION`：尚待驗證的設計或技術假設。
- `BLOCKED`：缺授權、資料、平台能力、存取權限或主辦確認。
- `FAILED`：實測不通過；附原因、替代方案與回退步驟。

**禁止用「應該可以」「理論上支援」替代實測證據。** 不要杜撰成功 build、API 路由、Figma token、模型 benchmark 或使用者研究。不能讀取 repo 或頁面時，寫明未檢查並使用 `TODO`，不得補出不存在的實作。

## 4. 優先級與操作守則

1. 在寫 code 前確認任務 ID 與優先級：`PRIORITIES.md` 是 backlog 的唯一排序來源。
2. P0 還有阻斷工作時，不主動開工 P2；若人類要求 P2，先解釋對 P0 的風險。
3. 修改範圍限當前 issue，避免大規模重構，保留官方 repository 慣例。
4. 採「一個最小可測改動 → 執行檢查 → 記錄證據」；不要一次修改跨多層的巨大檔案集合而無測試。
5. 每個提交包含明確功能開關與降級方式；不可讓未穩定模型阻斷文字主流程。
6. 任何新的依賴／字體／資料／模型權重都必須加入授權與來源紀錄，請負責人核准再合併。
7. 如測試失敗，先保留 reproducible logs（不含個資）並修 P0；勿為了讓 Demo 看起來成功而偽造資料。

## 5. Repo 與分工

上游參考（請以 checkout 的 commit 為準）：

- Flutter Host：`https://github.com/taipei-doit/TownPass`
- Vue Services：`https://github.com/taipei-doit/TownPass-Services`
- Developer Guide：`https://tpe-guideline.web.app/en/`
- UI Kit：`https://www.figma.com/design/n2cy2uJoMY58LRjgNz2MBF/`

預期技術：Flutter / Dart、Vue 3 / TypeScript / Vite、Flutter WebView bridge、裝置端 STT/LLM/TTS（僅實測及核准後啟用）、版本化的官方資料快照。

**不要臆造資料夾路徑、路由檔名、Vue 元件名或 bridge 方法。** 先搜尋實際 checkout，使用官方已有命名與架構；下面是建議契約而不是已存在 API。

角色代號：`L` PM/Integration，`F` Flutter/iOS，`A` AI/ML，`V` Vue/UI，`D` Data/QA。Agents 可以協助任何角色，但最終變更由人類 owner 審核。

## 6. 架構不變條件（Invariants）

**UI**：Vue（若主辦允許且官方架構支援）呈現導航、文字、翻譯、逐字稿確認、接力卡。Flutter/Native 負責麥克風、裝置端模型及設備能力。以最小而受控的 bridge 連接。

**資料流**：

`使用者語音 → 本機 STT → 使用者確認逐字稿 → （可選）本機意圖分類 → 使用者確認候選意圖 → 審核過的資料快照／官方來源 → 固定模板下一步 → 接力卡`。

- LLM 只可輸出白名單服務意圖與必要的結構化候選欄位；**不可決定政府事實**。
- 所有自由文字輸入需有長度限制；每次 LLM 輸出必須 schema validate，並限制 timeout 和並行任務。
- 未找到服務或資料已過期時，輸出「待確認」而不是捏造結果。
- 語音、LLM、TTS 不能用時，Basic Mode 仍可執行相同任務。
- 網路只用於允許的官方資料取得／更新等一般服務，不用於遠端 LLM 推論；預設不傳音訊、逐字稿或對話。
- 所有本機、遠端及分享資料的流向都要列出來，讓使用者知道什麼會離開手機。

## 7. 橋接 API 建議契約（先驗證平台可行性）

版本化訊息建議：

```json
{
  "version": 1,
  "requestId": "unique-id",
  "type": "getCapabilities",
  "payload": {}
}
```

可考慮的方法白名單：

- `getCapabilities`：取得本機已驗證的 STT/LLM/TTS 能力與可用語言；**不能只根據型號推斷**。
- `startRecording` / `stopRecording` / `cancelRecording`：明確啟停與取消，尊重權限。
- `transcribeAudio`：由 Native／Flutter 在本機取得語音結果；避免把原始音訊透過 WebView 傳到網頁或遠端。
- `classifyIntent`：裝置端受限分類；非法結果退回固定選單。
- `readServiceSnapshot`：只讀經核准的資料快照。
- `clearTaskState`：清除本機非必要任務資料。

必須做到：origin allowlist、訊息長度上限、版本及 type 驗證、requestId 對應、timeout/cancel、最小權限、不暴露任意 URL/檔案／shell 執行能力；且開啟離線模式後 bridge 仍可工作。若官方已提供更合理的契約，以其已核實版本為準。

## 8. AI 模型與語言規則

**選模型前一定先確認：**

- 完整模型名稱、repo URL、publisher、revision、quantization、runtime、weights 來源、hash。
- 各層授權：runtime、模型權重、tokenizer、訓練衍生條款、聲音模型；與競賽 AGPL 及安全來源要求是否相容。
- iOS／Android 真機可否載入，無網路時是否真能推論；是否能在預計的設備 RAM／儲存空間內工作。
- 語言支援應拆開記錄為 STT／LLM／TTS／UI／混語五個維度。

**候選不等於核准：** SEA-LION、Breeze、IBM Granite、Whisper、sherpa-onnx、whisper.cpp、Piper／系統 TTS 等都須單獨驗證。不得隨便新增中國大陸品牌／來源模型或權重，不論表面 License 為何。

如果使用生成模型，預設只提供受限意圖 JSON，例如：

```json
{"version":1,"intent":"digital_help","district":null}
```

程式必須有 enum allowlist、JSON schema、無效值 fallback、使用者確認。禁用 confidence 自報作為唯一決策信號；不產生服務日期、電話、地址、資格、申請結果或引用網址。

### 語言品質

- `zh-TW`：最先完成完整任務與華語 STT 真機測試。
- 台語：單獨測試台語、台華混語及口音；華語辨識通過不等於台語通過。
- 越南語：至少有一位母語者審閱核心固定文案；越南語自由語音需真實說話者測試。
- 其他語言：沒有完整能力證據不要在 UI 顯示已支援。
- 若 TTS 無法在離線環境中說某語言，顯示文字，或使用明確標示的經授權固定錄音；不能把華語 TTS 當台語。

## 9. 政府資料真實性

資料**必須從合法使用的正式開放資料或經主辦確認的來源取得**。每筆官方服務資料至少維護：

`id, service_type, district, source_url, source_published_at, retrieved_at, valid_until, license, review_status`。

只把 `review_status=approved` 且時間語意合理的紀錄列為目前有效；未知日期標「待確認」；過期資料不可顯示「正在開放」。

**嚴禁用一個月的數位協助據點時段填充另一個月。** Mock 資料只能在測試與展示標示為「模擬資料」；比賽要求使用公開資料的核心欄位不能由 mock 取代。

資料來源應可在 UI 點選；若離線無法開啟官方網站，至少保留來源文字、擷取時間和必要提醒。

## 10. 無障礙與 UX 不變條件

- 首頁提供並列的「語音」「文字」「直接選服務」路徑；文字不是難找的備援小字。
- 主 CTA 清楚；優先單一主要動作；按鈕可讀屏且至少符合可適用的 WCAG 2.2 AA。
- 目標觸控區建議至少 48 × 48 logical pixels，內文大字且可隨系統放大；**不憑單一推薦尺寸宣稱已符合全部 WCAG**。
- 停止錄音必須容易；不可要求長按、持續監聽或精準手勢。
- 顯示 STT 結果供修改；意圖不確定時顯示固定選項。
- 任何重要狀態使用文字+語意標籤，不只用顏色或聲音表達。
- 高齡者與新住民皆可以自主選擇語言，不依口音或國籍推測身分。
- UI 請沿用官方 Figma Design System；無法讀取時標示待確認，勿杜撰 token。

## 11. 連接到舊手機的降級策略

1. **Basic Mode 是最優先可用的 baseline**，不要強制首次下載 2–4GB 模型。
2. 輕量語音需先證明本地 STT 真機可用；否則回 Basic。
3. Full AI 只能在當前測試設備、當前模型版本的實測結果符合驗收後開放。
4. 模型載入失敗、記憶體不足、取消、超時或過熱時，保留已確認任務、釋放能釋放的資源並回 Basic；若 OS 直接終止需讓使用者重啟後可恢復。
5. 新模型不可自動取代已穩定的 Demo 版本；需要性能、準確率、版本與回退比較。

## 12. 測試、Benchmark 與證據

需要測試：

- Flutter build／Vue build、基本單元測試、schema 驗證、路由與返回。
- iPhone：型號、iOS、RAM 類別、Xcode／Flutter 版本、commit、模型 revision/quantization、執行日期。
- 飛航模式**重啟 App**，現場全新句子測試語音及 LLM（只要有宣稱支援）。
- STT：安靜／日常噪音、口音、空白、混語、可否修正；以適當 CER/WER 與服務意圖正確率檢查。
- 模型：載入、取消、超時、重入、離線、記憶體峰值、熱狀態、延遲（至少 p50、p95）。
- 文字任務：有效、過期、缺欄位、離線、官方頁無法開啟。
- 安全：QR 不含個資、資料可清除、橋接 origin/schema 白名單。
- 無障礙：大字、VoiceOver／TalkBack、焦點、對比、觸控範圍。
- 發布：連續 10 次主流程無阻斷崩潰；2 分鐘 Demo 彩排及備援機。

參考目標：Basic 冷啟動至可操作 p95 ≤5 秒；10 秒語音辨識 p95 ≤15 秒；LLM 意圖分類 p95 ≤15 秒。這些是**目標**不是已測結果；未達則評估降低模型或關閉能力。

**測試失敗時應誠實標示 FAILED，不可刪掉測試以製造通過紀錄。**

## 13. 每個 agent 開工前必須完成

1. 讀 `README.md`、`PRIORITIES.md`、`AGENTS.md`。
2. 列出要處理的 Issue ID 與想交付的最小可驗收成果。
3. 檢查目前 checkout、官方 repo 結構、測試環境與相關文件；不憑之前記憶猜檔名。
4. 確認是否需要新 dependency、模型、API、資料或設計資源；若需要，先提交授權／來源查核。
5. 告訴人類 owner：要改哪些檔案、可能影響哪些流程、怎麼回退。
6. 除非 owner 明確授權，不做 scope creep、刪除、force push、公開發布或外部服務部署。

## 14. 每個 agent 完工時必須回報（固定模板）

```text
Issue: <ID / title>
Status: VERIFIED / ASSUMPTION / BLOCKED / FAILED
Summary: <功能與用戶價值，最多 3 句>
Changed files: <實際更動路徑>
Architecture impact: <資料流、bridge、state、依賴變化>
Tests run: <命令、設備、版本、結果；沒跑就寫 NOT RUN>
Offline evidence: <有宣稱離線能力時附真機測試；否則 N/A>
Licenses and new dependencies: <名稱、版本、來源、審核狀態>
Known limitations: <未支援設備/語言、錯誤與風險>
Rollback: <如何安全關閉或回退>
Next recommended issue: <ID>
```

**不要只說「Done」或「應該可以」。** 如果不能執行命令、看不到 Figma、沒有 iPhone 實機，必須寫清楚限制；不可聲稱已完成真機驗收。

## 15. PR / Code Review Checklist

- [ ] 任務 ID、目的與範圍合理，沒有繞過 P0 關卡。
- [ ] 遵守既有專案結構、命名、lint／format 規則。
- [ ] 已執行可用的 build、lint、test；沒執行者有原因。
- [ ] 有完整文字／Basic fallback；不因音訊或模型故障無法完成主流程。
- [ ] 不會在遠端推論 LLM，沒有偷偷將音訊／逐字稿發到 API。
- [ ] 行政事實只使用來源可追溯且通過審核的資料。
- [ ] 新增套件、模型、資產、資料已加入授權／來源台帳；有疑慮就不合併。
- [ ] 無 token、密碼、真實受試者錄音或其他機密資料被提交。
- [ ] Flutter↔Vue bridge 的 message schema／origin／timeout 已檢查。
- [ ] UI 大字、讀屏、錯誤狀態已考慮；新增語言有母語審核或明確待驗證。
- [ ] 實測證據有設備、版本、日期；不能用模擬結果代替真機。
- [ ] 可回退；發表版本不包含未驗證功能。

## 16. 建議給 coding agent 的標準指令（可複製）

```text
請先閱讀本 repo 的 README.md、PRIORITIES.md 和 AGENTS.md。
你的工作任務是 <Issue ID>。先檢查實際專案結構與當前 checkout；
列出最小實作方案、會修改的檔案、相依、合規與風險。
只實作此 issue；保持官方架構慣例，不新增未審核的依賴、模型或外部 API。
完成後執行可用的 build/lint/test，回報實際命令與結果。
若涉及語音、LLM、裝置、語言或離線能力，不可以假裝已在真機驗證。
若卡在授權、官方規則、設備或文件權限，標示 BLOCKED 並給出安全的下一步。
務必保留文字／Basic Mode 及可回退路徑。
使用 AGENTS.md 第 14 節的格式回報。
```

---

本文件約束**開發代理的行為**，不是要求其自行決定主辦規則、政府資料真實性或使用者研究結果；該類事項必須由負責的人類隊友確認。
