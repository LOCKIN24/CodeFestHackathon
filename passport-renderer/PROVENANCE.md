# Embedded passport provenance and contract

The renderer is adapted from the user-supplied `milk-passport-demo-refined` project. Its low-poly book, cover/paper/stamp textures, opening/stamping/page-turn timelines, stamp hit tests, gesture thresholds, detail sheet, reduced-motion and paper fallback are preserved. The original supplied project is retained separately; this canonical source includes the approved integration refinements.

`scene.js` adds GPU disposal and removable context listeners. `browsing.js` adds lifecycle-bound event listeners and suspension/disposal. `main.js` replaces the standalone demo's allowance/claim/progress controls with a read-only native host; `host-state.js` validates strictly sanitized record projections. The historical demo `progress.js` and its original tests remain for regression provenance but are not imported/bundled in the app asset. There is no browser storage or new persistence and no network resource dependency.

The embedded app asset is `../TownPass/assets/passport/passport.html`. It contains Three.js **0.180.0** under the MIT License; the complete license is shipped alongside at `THREE-LICENSE.txt`. Vite **7.1.12** is build tooling only. The original user-authored art/scene code retains its existing ownership; this work does not assign it a new third-party license.

## Native API

`window.milkPassportHost.setRecords({version:1,stamps:[{id,type,week,date}],replayLatest:false,reduceMotion:false})` returns a boolean. Stamps must have only those four fields. `type` is `milk` or `soy`, `week` is a Monday `YYYY-MM-DD`, `date` starts with a valid `YYYY-MM-DD` inside that week, and `id` is 1–100 ASCII letters/digits/underscores/hyphens. IDs and weeks are unique. No names, card numbers, addresses, schools, credentials or child identifiers are needed.

This is a display API, never a claim or redemption API. `replayLatest` animates only an existing record and is idempotent across native ready/onLoadStop bootstrap callbacks. The on-screen replay control can replay it again without changing the provided records. `getState()` returns a defensive copy for validation. The native host may invoke `suspend()`, `resume()` and `dispose()`; disposal is final and rejects subsequent payloads. The page notifies `flutter_inappwebview.callHandler('passportReady',{version:1})` when available, including the platform-ready event. Native onLoadStop injection is a supported independent fallback.

CSP blocks network connections, frames, remote assets, forms and objects. The only scripting/styles are the bundled inline app. WebGL 2 is optional; missing/lost contexts use the original paper fallback. The host creates no continuous idle animation; collection and browse RAF are canceled on suspend. Disposing disconnects observers/listeners, releases textures/materials/geometries/render targets and WebGL context.

## Verification

Run `npm test` for the original progress/gesture regression cases and native host contract tests. Run `npm run build` to regenerate the standalone Flutter asset. Browser QA has covered mobile 390×844 and 320×640, active WebGL, upright cover, open/turn/details/replay, static fallback, pause/resume and context disposal. Native iOS integration coverage is in `../TownPass/integration_test/milk_passport_webview_test.dart`.

The host uses a front-facing idle camera/book pose, a locally loaded Songti TC serif title, lower cover emblem and 64px lower controls. Decorative animation captions and the arrow emoji are not part of the app UI. Operational accessibility announcements remain.
