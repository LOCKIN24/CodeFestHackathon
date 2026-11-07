# iPhone manual verification checklist

The five physical navigation flows reported by the project owner are recorded below; this session did not observe them. They do not establish that every feature or control works. Record date, app commit, iOS version, network, result and any prompt for each item. Do not enter personal data or submit forms, pay, place calls, or change settings during this pass.

1. Open Home and check banner, 活動訊息 and account icon. Switch to 服務, 優惠 and 帳務, then return to 首頁. Record blank screens, loading errors and back behavior.
2. From Home open 活動訊息 > 更多, select a visible activity, then return to Home. Note whether data and images load. Do not assume list/detail work without their passed objects.
3. Open 帳戶 > 設定 > 語言. Verify the two displayed choices and back navigation without changing them. Source callback is empty; do not record language switching as working without separate evidence.
4. From 服務 open 申辦服務. Confirm the page title, 申辦 / 查詢, search and a category expansion. Return using WebView close and confirm the host screen. Do not submit an application.
5. From 服務 > 我的服務 > 更多, find 圖書借閱, open it and inspect 館藏查詢, 我的紀錄 and 分館地圖. Record key/billing or permission errors; avoid enabling location unless the device owner chooses to. Open search and return to the host.
6. For each tested screen, separately record navigation via normal UI, any deep-link test, accessibility labels with VoiceOver, permissions, errors, and back/close behavior. A successful simulator or local-browser test is not an iPhone test.

Previously observed on simulator: all four tabs and embedded Perks page. Previously observed in a local browser: application home, library home and library keyword-search navigation. No direct opening, authentication, real transactions, voice, AI or bridge round trip is verified by those observations.

## Project owner physical-iPhone report

The project owner reports manually verifying these exact UI flows. This is user-reported physical-device evidence, not an agent-observed test, and does not verify direct programmatic navigation, transactions, settings changes, every control, or accessibility:

1. 首頁 → 服務 → 優惠 → 帳務 → 首頁
2. 首頁 → 帳戶 → 設定 → 語言
3. 首頁 → 活動訊息 → 更多 → 活動詳情
4. 服務 → 申辦服務 → 搜尋／展開分類
5. 服務 → 我的服務 → 更多 → 圖書借閱

Device model, OS version, app revision and execution date were not supplied; capture them in future testing. Keep other feature and back-navigation checks pending.
