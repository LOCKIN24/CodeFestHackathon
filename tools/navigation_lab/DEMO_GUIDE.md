# TownPass Navigation Lab — demo guide

This is a **local, read-only preview**, not an app integration. No screen opens and no payment, submission, call, account change, or other app action is performed. The model can misclassify both features and actions; “Action allowed: No” applies to every result. A source-audited path is not proof that the destination works on a device.

## Before the demo

You need this workspace and its `docs/` registries, Python 3, a browser, and a locally running Ollama server with `qwen3:4b` already installed. The current model is approximately 2.5 GB on disk and used about 3.2 GB when loaded during earlier testing; available memory and startup time vary. There are no Python packages to install. Keep Ollama and the preview server on loopback; do not expose either publicly. This guide does not install software or download models.

From a terminal:

```sh
cd /Users/quentinchih/Documents/hackathon
python3 --version
ollama list
curl --max-time 3 http://127.0.0.1:11434/api/tags
```

Confirm `qwen3:4b` appears in the installed model list and the API responds. In a terminal left running, start the preview:

```sh
cd /Users/quentinchih/Documents/hackathon
python3 tools/navigation_lab/preview_server.py
```

Open [http://127.0.0.1:8765/](http://127.0.0.1:8765/). If this port is occupied, use `python3 tools/navigation_lab/preview_server.py --port 8766` and open `http://127.0.0.1:8766/`. Stop the server with Ctrl-C in its terminal. The model may take a while to load on the first request.

## Five navigation previews

These were successful in the recorded regression run. Enter one at a time, then show the feature ID, `browse_or_navigate`, source-backed screen/control steps, prerequisites, and the explicit no-action notice. Model results can vary; if the model asks for clarification, name the feature more explicitly and do not present the outcome as a verified app route.

| Request | Expected feature | What to show |
|---|---|---|
| 可以找語言設定頁給我看嗎？ | `language_settings` | Steps to `flutter.language`; the locale-change callback is empty. |
| 訊息中心在哪，讓我看一下 | `messages` | Recorded path and message controls; dependencies and mock limitations. |
| 可以看我的帳戶頁面嗎 | `account` | Source-backed account path; runtime and identity remain unverified. |
| 我想瞧瞧基本資料 | `personal_information` | Steps to basic information and listed prerequisites. |
| 要從哪看意見回饋頁 | `feedback` | Feedback path; its send handler is unimplemented. |

These paths are previews with unverified prerequisites. They do not enable the underlying feature or perform an action.

## Clarification and rejection

| Request | Expected result |
|---|---|
| 我想看城市天氣 | Clarification: the topic is unsupported. |
| 我要查票夾或圖書館 | Clarification: choose one destination. |
| 先看票夾，再替我買一張票 | Rejection: mixed browsing and real action. |

The classifier has also clarified some action requests instead of explicitly rejecting them. A clarification or preview never grants permission to execute an action.

## Two limitation demonstrations

- **最近有啥活動可以看？** — `activity_information` should show an incomplete preview. The audited activity list requires an `ActivityList`; the lab cannot fabricate it. A specific activity detail also needs an `ActivityItem`.
- **圖書借閱在哪個頁面？** — `library_services` should show an incomplete path and recorded boundary evidence. The audit does not establish a complete Flutter-to-WebView-to-Vue path or runtime reachability.

Other recorded limitations are important to disclose: the frozen holdout wrongly accepted **查看首頁的空氣品質指數** as Home and **Can I view stock prices in the account section?** as Account. A multiple-destination request was also accepted as one feature. These are known false acceptances, not supported features. Do not rely on the model to decide that an action is safe.

## If something is unavailable

- **Ollama API does not respond:** check `ollama list` and `curl --max-time 3 http://127.0.0.1:11434/api/tags`. Start the installed Ollama app or run `OLLAMA_HOST=127.0.0.1:11434 ollama serve` in a separate terminal, then retry the curl command. If the port is already in use, inspect it with `lsof -nP -iTCP:11434 -sTCP:LISTEN`; do not start a second server on that port. Keep it bound locally.
- **`qwen3:4b` is missing or Ollama is not installed:** the full demo requires that local setup. Do not download or install anything during this freeze; arrange any installation or model download separately with approval. Without the model, requests needing interpretation should clarify rather than produce a model-backed match.
- **Preview page is unavailable:** check the terminal running `preview_server.py` and start it again using the command above. Use `curl --max-time 3 http://127.0.0.1:8765/` to check the server; if the port is occupied, use `--port 8766`. Open the matching loopback URL.
- **A request stalls or produces a different answer:** allow time for local model loading, check the Ollama API, and retry a named feature. Results are nondeterministic and conservative clarification is expected. Do not change the audited registries or invent missing paths for the demonstration.

For the preserved test results and the limitations of their small, hand-labeled corpora, see `TEST_RESULTS.md`. The current prototype is not approved for device integration.
