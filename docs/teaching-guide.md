---
tags: AI-3008, Trainer, Teaching
---

# AI-3008 備課指南（Trainer-only）

> 本文件是給**講師**用的備課指南，刻意不放進對學員的 [`README.md`](../README.md)。
> 內容對應課程 **AI-3008-A：Extract insights from visual data on Azure**（從視覺資料中萃取洞察）。
> Demo 環境（Terraform）細節見 [`docs/demo-environment.md`](./demo-environment.md)。

---

## 1. 課程概覽（先掌握全貌）

| 項目 | 內容 |
| --- | --- |
| 課程全名 | Extract insights from visual data on Azure（AI-3008-A） |
| 時長 | 1 天（ILT） |
| 對象 | 開發者、AI 工程師、技術人員 |
| 先備知識 | 熟悉 Azure 與 Microsoft Foundry、具基本程式經驗（Python） |
| 學習路徑 | https://learn.microsoft.com/training/paths/insight-visual-data/（8 模組） |
| 核心服務 | Microsoft Foundry、Azure OpenAI（多模態/影像/影片模型）、Azure Content Understanding、Azure Document Intelligence、Azure AI Search |

**一句話定位**：教學員打造能「**看懂**圖片與文件、並對其**推理/萃取結構化資訊**」的應用 —— 結合多模態
模型、Content Understanding、Document Intelligence 與知識探勘（Knowledge Mining）。

**⚠️ 重要：這是改版後的新課**。舊的 AI-3008 是「Azure AI Language（NLP）」，已被完全取代。備課時
不要參考任何舊的 NLP 教材。

---

## 2. 課程地圖：8 個模組

| # | 模組 | 主要服務 | 對應 Lab |
| --- | --- | --- | --- |
| 1 | Develop a vision-enabled generative AI application | Azure OpenAI 多模態模型 | vision/01-gen-ai-vision |
| 2 | Generate images with AI | GPT-Image / FLUX（OpenAI Image API） | vision/02-generate-image |
| 3 | Generate videos with Microsoft Foundry | Sora 2 | vision/03-generate-video |
| 4 | Analyze images with Content Understanding | Content Understanding | vision/04-content-understanding |
| 5 | Create a multimodal analysis solution with CU | Content Understanding（文件/音訊/影片） | info-extraction/01-content-understanding |
| 6 | Create a Content Understanding client application | Content Understanding REST API | info-extraction/02-content-understanding-api |
| 7 | Extract data with Azure Document Intelligence | Document Intelligence | info-extraction/03-document-intelligence |
| 8 | Create a knowledge mining solution with AI Search | Azure AI Search | info-extraction/04-knowledge-mining |

> Lab 來自兩個 Microsoft Learning repo：
> [`mslearn-ai-vision`](https://microsoftlearning.github.io/mslearn-ai-vision/)（模組 1–4）與
> [`mslearn-ai-information-extraction`](https://microsoftlearning.github.io/mslearn-ai-information-extraction/)（模組 5–8，另含 05-rag-pipeline）。
> 目前**沒有**正體/簡體中文 Lab repo，只有英文版。

---

## 3. 建議議程與時間分配（1 天約 6.5 小時教學）

| 時段 | 內容 | 約略時間 |
| --- | --- | --- |
| 開場 | 自我介紹、課程定位、AI workload 全景、環境/Lab 登入 | 30 min |
| 模組 1 | Vision-enabled app（多模態 + ChatCompletions vs Responses API） | 45 min |
| 模組 2 | Generate images（GPT-Image / Image API） | 30 min |
| 模組 3 | Generate video（Sora 2） | 25 min |
| ☕ 休息 | | 10 min |
| 模組 4 | Analyze images with Content Understanding | 35 min |
| 模組 5 | Multimodal CU（文件/音訊/影片） | 45 min |
| 🍱 午休 | | 60 min |
| 模組 6 | Content Understanding client app（REST API） | 35 min |
| 模組 7 | Document Intelligence | 45 min |
| 模組 8 | Knowledge mining（AI Search） | 45 min |
| 收尾 | Q&A、Learn profile/成就碼、問卷 | 20 min |

> 彈性：模組 8（Knowledge Mining）在投影片講者備註中標註「可視情況略過，僅為完整性而納入」。
> 時間不夠時可改為**講師 demo** 而非讓學員自己做。

---

## 4. 貫穿全課的核心觀念（建議開場與適時強調）

### 4.1 AI workload 全景（開場用）
先讓學員理解整個 AI workload 地圖：Generative AI & Agents、Text & Language、Computer Speech、
**Computer Vision**、**Information Extraction**。本課焦點是後兩者，但要強調：**生成式 AI 與 Agent 越來
越是「疊在」這些基礎 workload 之上**。

### 4.2 ChatCompletions API vs Responses API（模組 1 關鍵，務必講清楚）
這是全課最重要的觀念之一，投影片有並排比較：

| | ChatCompletions API | Responses API |
| --- | --- | --- |
| 狀態 | **無狀態**：client 每次送出完整對話歷史，payload 逐回合變大 | **有狀態**：server 管理狀態，app 只送最新 input + 上一個 response ID，payload 維持固定 |
| 取得輸出 | `response.choices[0].message.content` | `response.output_text` |
| 呼叫 | `client.chat.completions.create(...)` | `client.responses.create(...)` |
| 定位 | 控制力高、較複雜 | 較簡單，**新應用首選**（整合了 chat completions + assistants 的優點） |

**講者重點台詞**：「兩種 API 都遵循 initialize → call → get output → update state 的流程。除非你需要
自己管理對話記憶，否則新專案請優先使用 Responses API。」

### 4.3 模型生命週期（務必提醒，且每次開課前重新確認）
Azure 模型有淘汰時程，**過期或即將過期的模型不要用**。本課/Demo 使用（截至 2026-06-08 驗證）：

| 角色 | 模型 | 狀態 |
| --- | --- | --- |
| Chat / vision | `gpt-5.4` | GA（投影片/Lab 用 `gpt-4.1`，但 2026-10-14 淘汰） |
| 影像生成 | `gpt-image-2` | GA（與目前 Lab 一致） |
| 嵌入 | `text-embedding-3-large` | GA |
| Content Understanding 補全 | `gpt-5.2` | GA（CU 目前僅支援 `gpt-4.1`/`gpt-5.2`） |
| 影片 | `sora-2`（2025-12-08 版） | Preview |

備課前請查：https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement

### 4.4 每個練習都要先建立 Foundry 專案（管理學員預期）
投影片講者備註明說：**每個練習都從「建立 Foundry 專案」開始**，學員一天下來會做很多次。要先說明
這是刻意設計（讓每個練習模組化、避免浪費 Azure 資源），否則學員會覺得很煩。

### 4.5 安全/驗證：本環境一律用 Entra ID（無金鑰）
若使用我們的 Terraform 備援環境，提醒這是**純 Entra ID（AAD）驗證、停用所有 access key** 的設計
（符合企業資安政策）。這也是真實世界企業常見的鎖定，值得當作教學亮點帶過。

---

## 5. 逐模組備課指南

> 每個模組的結構：**學習目標 → 講解重點 → Demo/Lab → 常見問題/坑 → 重要連結**。

### 模組 1：Develop a vision-enabled generative AI application
**學習目標**：能用多模態模型對「圖片 + 文字」的提示作答；理解 ChatCompletions vs Responses API。

**講解重點**
- 什麼是多模態（multimodal）模型：可同時接受文字與影像輸入。
- 多模態提示的結構：一個 user message 內含「多個 part」（一個 text part + 一個 image part）。
- 影像可用兩種方式帶入：**URL** 或 **base64 二進位資料**（`data:image/...;base64,...`）。
- 帶出 4.2 的 API 比較（這是本模組核心）。

**Demo/Lab**：[01-gen-ai-vision](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/01-gen-ai-vision.html)

**常見問題/坑**
- 「哪種模型能處理視覺輸入？」→ **多模態模型**（GPT-5 系列、GPT-4.1 系列、o 系列等皆可），不是只有
  embedding 或特定模型。
- 「如何送出含圖片的提示？」→ **一個多部位的 user message，同時含 text 與 image**，不是分兩次送。
- 投影片範例 ChatCompletions 用 `Phi-4-multimodal-instruct`，Responses 用 `gpt-4.1`；我們的 Demo 用
  `gpt-5.4`（皆支援 vision）。

**連結**
- Use vision-enabled chat models: https://learn.microsoft.com/azure/ai-foundry/openai/how-to/gpt-with-vision
- Responses API: https://learn.microsoft.com/azure/ai-foundry/openai/how-to/responses

---

### 模組 2：Generate images with AI
**學習目標**：在 playground 與程式中用影像生成模型，依自然語言提示生成原創影像。

**講解重點**
- 部署影像生成模型：`GPT-Image`、`FLUX.1-Kontext-pro` 等。
- Playground 操作：選影像尺寸、輸入提示、（若支援）附參考圖。
- 用 **OpenAI Image API** 在程式中生成影像。
- 推論工作（inference task）篩選：找影像生成模型要用 **Text to image**。

**Demo/Lab**：[02-generate-image](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/02-generate-image.html)

**常見問題/坑**
- Knowledge check：找影像生成模型要篩 **Text to image**（不是 Image to text / Embeddings）。
- 影像生成模型用哪個 OpenAI API？→ **Image** API。
- **配額（quota）**：`gpt-image-2` 在某些訂閱配額很小（例如 limit 4）。Demo 前先確認配額，必要時改用
  `gpt-image-1.5`（配額較多）或調整既有部署容量。

**連結**
- Image generation how-to: https://learn.microsoft.com/azure/foundry/openai/how-to/dall-e

---

### 模組 3：Generate videos with Microsoft Foundry
**學習目標**：用 Sora 2 從文字提示生成影片。

**講解重點**
- `Sora 2` 可從文字提示、參考圖或既有影片混搭，生成擬真場景。
- 影片生成是**非同步**流程：送出 job → 輪詢狀態 → 完成後取回影片。
- 寫好影片提示的訣竅（像在描述分鏡）：鏡頭取景（wide/medium/close-up）、主體與特徵、分小步驟的動作、
  光線/色調/風格。可現場用投影片的 1980s sci-fi 範例示範。

**Demo/Lab**：[03-generate-video](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/03-generate-video.html)

**常見問題/坑**
- Sora 2 仍是 **Preview**、且有配額/區域限制，**Terraform 不一定能可靠部署**，建議**手動在 Foundry portal
  部署**（用 `2025-12-08` 版；`2025-10-06` 版 2026-07-15 淘汰）。
- 生成耗時，課堂上先準備好或邊講邊等。

**連結**
- Video generation with Sora 2: https://learn.microsoft.com/azure/foundry/openai/concepts/video-generation

---

### 模組 4：Analyze images with Content Understanding
**學習目標**：用 Azure Content Understanding 分析影像、自訂 analyzer。

**講解重點**
- Content Understanding 是 Foundry Tools 的**多模態內容分析**：影像、文件/表單、音訊、影片。
- 由 AI 驅動的資訊萃取：**prebuilt 與 custom analyzer**、單樣本/少樣本 schema 訓練。
- 流程：用一張或多張訓練影像定義 analyzer 的 **schema** → 用 Content Understanding API 跑 analyzer 取得結果。
- 強調看 JSON 回應中的欄位值，就是你 app 要用的資料。

**Demo/Lab**：[04-content-understanding (vision)](https://microsoftlearning.github.io/mslearn-ai-vision/Instructions/Exercises/04-content-understanding.html)

**常見問題/坑**
- 建立 CU 專案要用 **Content Understanding Studio**（不是 VS、不是 Azure ML studio）。
- 要萃取的資訊要先定義 **schema**（不是 index、不是 cluster）。

**連結**
- What is Content Understanding: https://learn.microsoft.com/azure/ai-services/content-understanding/overview
- Analyzer 概念: https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/analyzer-reference

---

### 模組 5：Create a multimodal analysis solution with Content Understanding
**學習目標**：用 CU 分析文件、音訊、影片，萃取/生成欄位。

**講解重點**
- 文件：從發票萃取關鍵欄位以自動化付款流程。
- 音訊：摘要會議通話、判斷客服錄音情緒、從電話留言萃取資料。
- 影片：從會議錄影抽重點、摘要簡報、偵測安全錄影中的特定活動。
- 建立 analyzer 四步驟：建立 Foundry 專案 → 定義 schema（可基於內容樣本 + analyzer 範本）→ 依 schema
  建立 analyzer → 用 analyzer 對新內容萃取/生成欄位。
- **custom analyzer 可基於 prebuilt analyzer**（例如 `prebuilt-document`）。

**Demo/Lab**：[01-content-understanding (info-extraction)](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/01-content-understanding.html)

**常見問題/坑**
- CU 設計用途：**從文件/影像/影片/音訊萃取資訊的 analyzer**（不是聊天機器人、不是影像生成器）。
- **CU 需先設定資源層級的預設模型部署**（`PATCH /contentunderstanding/defaults`）才能建立 analyzer。
- analyzer id **不能含 `-`**（連字號）。

**連結**
- Prebuilt analyzers: https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/prebuilt-analyzers
- 建立 custom analyzer 教學: https://learn.microsoft.com/azure/ai-services/content-understanding/tutorial/create-custom-analyzer

---

### 模組 6：Create a Content Understanding client application
**學習目標**：用 Content Understanding REST API 建立 analyzer、分析內容。

**講解重點**
- 準備用 API：建立 Foundry 專案、用 **Entra ID 或 endpoint + API key** 驗證；用 Foundry SDK + Entra ID
  可自動取得連線資訊。
- 定義 schema 並建立 analyzer 的關鍵元件：
  - `baseAnalyzerId`（基礎 analyzer，如 `prebuilt-document`）
  - `fieldSchema`（欄位：type、method（extract/generate）、description）
  - `models`（completion 與 embedding 模型）
- 分析內容：驗證 client → 開始分析（給 `analyzer_name` 與 input：URL 或二進位）→ 取回結果 → 萃取內容。

**Demo/Lab**：[02-content-understanding-api](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/02-content-understanding-api.html)

**常見問題/坑**
- GA REST API 版本是 `2025-11-01`；建立 analyzer 是 **PUT + 輪詢 `Operation-Location`** 的非同步流程；
  加 `allowReplace=true` 可重複執行（idempotent）。
- `method` = `extract`（從內容抽出）或 `generate`（由模型生成，例如摘要）。

**連結**
- 模型部署選項（CU 支援哪些模型）: https://learn.microsoft.com/azure/ai-services/content-understanding/concepts/models-deployments
- REST 快速入門: https://learn.microsoft.com/azure/ai-services/content-understanding/quickstart/use-rest-api

---

### 模組 7：Extract data with Azure Document Intelligence
**學習目標**：用 Document Intelligence 的 OCR 與深度學習模型，從表單/文件萃取文字、鍵值對、表格、結構化資料。

**講解重點**
- Prebuilt 模型（發票、收據、身分證件、名片、一般文件等）vs **custom 模型**（自己訓練）。
- 與 Content Understanding 的關係：CU 較新、是多模態統一體驗；Document Intelligence 專注文件、模型成熟、
  custom 訓練彈性大。可帶一句兩者定位差異（常見學員疑問）。
- Document Intelligence Studio 操作。

**Demo/Lab**：[03-document-intelligence](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/03-document-intelligence.html)

**常見問題/坑**
- 學員常問「CU 和 Document Intelligence 該用哪個？」→ 文件導向、需要成熟 prebuilt/custom 模型用
  Document Intelligence；要跨模態（含音訊/影片）或用 LLM 生成欄位用 CU。CU 的 `prebuilt-read`/`prebuilt-layout`
  也已把部分 Document Intelligence 能力帶進 CU。
- 若用我們的 AAD-only 環境：Document Intelligence 帳號需設 **custom subdomain** 才能用 AAD（已在 Terraform 處理）。

**連結**
- What is Document Intelligence: https://learn.microsoft.com/azure/ai-services/document-intelligence/overview?view=doc-intel-4.0.0
- 文件處理模型總覽: https://learn.microsoft.com/azure/ai-services/document-intelligence/model-overview?view=doc-intel-4.0.0

---

### 模組 8：Create a knowledge mining solution with Azure AI Search
**學習目標**：用 Azure AI Search 建立知識探勘方案：萃取並豐富資料，使其可搜尋。

**講解重點**
- Azure AI Search 三大能力：智慧索引（含影像）、**AI enrichment**（用 AI skills 豐富索引資料）、向量化（支援 agentic 工作負載）。
- 三大應用：企業搜尋、RAG（為 LLM 提供 grounding）、**Knowledge Mining**（本課焦點）。
- **Indexer** 從資料來源萃取資料；document cracking 取出文字；**enrichment pipeline** 逐步建立每份文件的 JSON 表示。
- 欄位可被「從來源萃取」或「在 pipeline 中推論/生成」。
- 內建 AI skills：語言偵測、實體萃取、關鍵詞、翻譯、PII、從影像 OCR、影像 caption/tag、多模態向量化。
- **Custom skills**：自訂邏輯（常是包裝其他服務，如 Azure Language）。
- 索引欄位屬性：key / searchable / filterable / sortable / facetable / retrievable。
- **Knowledge store**：把 projection 存到 Azure Storage（Objects=JSON、Tables=關聯式、Files=影像）。

**Demo/Lab**：[04-knowledge-mining](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/04-knowledge-mining.html)
（進階：[05-rag-pipeline](https://microsoftlearning.github.io/mslearn-ai-information-extraction/Instructions/Exercises/05-rag-pipeline.html)）

**常見問題/坑**
- 排程萃取/豐富資料以填入索引的元件是 **Indexer**（不是 projection、不是 query）。
- 哪個能產生關聯式 schema 的 projection？→ **Table**。
- 投影片講者備註：此段「可略過，僅為完整性納入」、且建議**講師先設好直接展示**。我們的 Demo 環境
  已自動建好 index（12 筆文件），可直接展示查詢結果。

**連結**
- AI enrichment: https://learn.microsoft.com/azure/search/cognitive-search-concept-intro
- Knowledge store: https://learn.microsoft.com/azure/search/knowledge-store-concept-intro
- CU skill in AI Search: https://learn.microsoft.com/azure/search/cognitive-search-skill-content-understanding

---

## 6. 預期學員問題 Q&A（先準備好答案）

- **Q：Content Understanding 和 Document Intelligence 差在哪？該用哪個？**
  A：見模組 7。CU 多模態、新、用 LLM 生成欄位；Document Intelligence 專注文件、prebuilt/custom 成熟。
- **Q：ChatCompletions 還是 Responses API？**
  A：新專案用 Responses（有狀態、較簡單）；需要自管對話記憶才用 ChatCompletions。
- **Q：為什麼每個 Lab 都要重建 Foundry 專案？**
  A：刻意設計，讓練習模組化、不浪費資源。
- **Q：這堂課有「技能型認證（Applied Skills / skill-based credential）」嗎？**
  A：**沒有**。目前只有課程**成就碼（Achievement Code）**。Applied Skills 有相鄰主題（如 AI-3004
  Vision、Develop generative AI solutions with Azure OpenAI），但沒有對應本課的。開課前可再查
  https://learn.microsoft.com/credentials/browse/?credential_types=applied%20skills
- **Q：模型會不會過期？**
  A：會，務必查 retirement schedule；本課用 GA 且未淘汰的模型。
- **Q：可以用 access key 嗎？**
  A：（若用我們的環境）企業政策停用金鑰，一律 Entra ID + 受控識別 + RBAC。

---

## 7. 課前準備清單（開課前 1–2 天）

- [ ] 重新確認模型 **retirement schedule**，需要時更新 Demo 用的模型版本。
- [ ] 確認目標訂閱在所選區域的**配額**（`gpt-5.4`、`gpt-image-2`/或替代、`text-embedding-3-large`、`gpt-5.2`）。
- [ ] 確認 **AI Search 容量**（eastus2 常缺；Terraform 預設 `search_location=eastus`）。
- [ ] （如要用備援環境）`terraform apply` 部署，並驗證資料面（CU analyzer、AI Search index 12 筆文件）。
- [ ] 手動部署 **Sora 2**（影片）、必要時 FLUX / Phi-4。
- [ ] 確認 Skillable Lab 與訓練金鑰、ESI 登入正常。
- [ ] 準備好影像生成/影片生成的範例提示（耗時，先暖機）。
- [ ] 自訂投影片：把 Lab 環境連結填到各 Exercise 投影片、移除「Trainers:」提示箭頭。
- [ ] 自我介紹投影片（Intro 第 3 張）填上你的資訊。

---

## 8. 講師小技巧

- **重複的「建立 Foundry 專案」**先講清楚是刻意設計，降低學員不耐。
- **影片/影像生成耗時**：邊等邊講概念，或預先生成好結果展示。
- **Knowledge Mining** 時間不夠就改成講師 demo（投影片備註也這樣建議）。
- 善用 **Knowledge check** 投影片：先讓學員思考再揭曉答案（本指南各模組已附正解）。
- 把 **Responses vs ChatCompletions** 和 **CU vs Document Intelligence** 兩個比較當作全課的記憶錨點，
  學員最常在這兩處混淆。
- 收尾提醒學員到 Microsoft Learn 建立 profile、領取課程**成就碼**、填**問卷**（aka.ms/ai3008survey）。

---

## 參考
- 學習路徑：https://learn.microsoft.com/training/paths/insight-visual-data/
- 課程頁：https://learn.microsoft.com/training/courses/ai-3008
- Vision Lab：https://microsoftlearning.github.io/mslearn-ai-vision/
- Information Extraction Lab：https://microsoftlearning.github.io/mslearn-ai-information-extraction/
- 模型淘汰時程：https://learn.microsoft.com/azure/ai-foundry/concepts/model-lifecycle-retirement
