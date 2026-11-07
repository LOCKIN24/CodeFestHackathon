# TownPass navigation lab

This Python standard-library prototype previews navigation using the source-audited registries. The authenticated development mobile API feeds a Flutter assistant; Flutter independently allows a small set of verified destinations after independent runtime validation. The lab itself does not execute routes or actions. It does not modify `allowed_ai_actions` or execute URLs, payments, submissions or other actions. Ollama is contacted only at `127.0.0.1:11434`; keep its server local.

## Demo scope

Implemented: local intent and feature matching, audited registry lookup, a loopback browser UI, read-only previews with missing-data and limitation reporting, and a narrowly allowlisted Flutter navigation executor. Simulated: navigation steps and outcomes; no app screen opens and no action can be executed. Unverified: runtime reachability, cross-platform WebView transitions, live services, permissions, typed runtime objects, and classifier reliability. The independent holdout found false acceptances and action requests that were clarified rather than rejected. See [DEMO_GUIDE.md](DEMO_GUIDE.md) for the demo script and recovery steps, and `TEST_RESULTS.md` for the recorded results.

## Run

With local Ollama running and `gemma3:4b` installed (override with `NAV_LAB_MODEL`, for example `qwen3:4b` for rollback):

```sh
python3 tools/navigation_lab/simulator.py
python3 -m unittest discover -s tools/navigation_lab -p test_lab.py -v
python3 tools/navigation_lab/safety_eval.py tools/navigation_lab/independent_cases.json --output tools/navigation_lab/my_regression_results.json
python3 tools/navigation_lab/summarize_safety.py tools/navigation_lab/my_regression_results.json
```

The regression command uses the live local model for requests that pass deterministic intent checks and writes results incrementally. Keep the distributed `regression_results.json` and `holdout_results.json` as recorded baselines by choosing a different output filename. To repeat the holdout with the same frozen rule hashes, run:

```sh
python3 tools/navigation_lab/safety_eval.py tools/navigation_lab/holdout_cases.json --freeze tools/navigation_lab/holdout_rule_freeze.json --output tools/navigation_lab/my_holdout_results.json
python3 tools/navigation_lab/summarize_safety.py tools/navigation_lab/my_holdout_results.json
```

Ollama may return different classifications on another run. The model uses a 4,096-token context and structured JSON with no tools; it can propose an intent and an existing feature ID or null, never a route, URL, argument or command. Historical development comparisons remain in `evaluation_results.json`; `evaluate.py` and `summarize.py` are the earlier comparison utilities and do not represent the full revised live-model intent stage.

## Matching and intent

Every request passes a structured intent stage before feature selection. Intent is one of `browse_or_navigate`, `perform_real_action`, `mixed_browse_and_action`, `unsupported`, or `ambiguous`. Deterministic checks reject clear actions and mixed requests and flag known unsupported topic families or ambiguity. Remaining browse requests go to the local model, which proposes only an intent and a catalog feature ID; a disagreement, invalid response, unknown ID, missing evidence, or unavailable model leads to clarification or rejection. Exact names and aliases remain supported but do not override the intent stage. This conservative logic may miss paraphrases or misclassify requests. Its result is never an authorization.

All responses explicitly state `action_allowed: false`. The local preview cannot call Flutter, Vue, JavaScript bridges, OS actions or external services; only Flutter can open its own allowlisted routes after independent runtime validation. Payment-history wording is distinguished from payment execution. Source-backed history stops at the recorded WebView boundary; no hosted URL is opened.

## Navigation integrity and evaluation

A deterministic breadth-first search uses recorded screen-to-screen edges from `flutter.main` and registered controls. It does not infer Flutter-to-Vue or WebView transitions. An incomplete path includes separately labeled source evidence and unresolved parameters or prerequisites; it does not establish runtime reachability. Specific items require clarification, and `ActivityList`, `ActivityItem` and `MessageItem` are never invented. Feature limitations, mock dependencies, route audit, controls, and screen states remain visible where present.

`test_lab.py` retains the original 23 labeled cases; `extra_cases.json` contains 86 additional cases. `evaluate.py` runs both and stores each raw model ID, baseline ID, hybrid decision, category, and preview status. `summarize.py` generates counts and individual errors. The corpus informed development of the rules and is not an independent holdout; do not generalize its scores. Status `preview` is still a source-only simulation with unverified prerequisites, `incomplete` identifies an audit gap or missing parameter, `clarify` asks for information, and `rejected` refuses a requested action or invalid ID. `TEST_RESULTS.md` describes the latest recorded run and its limits.

## Local browser preview

```sh
python3 tools/navigation_lab/preview_server.py
```

Open [the local preview](http://127.0.0.1:8765/) in your browser. Use `--port 8766` to choose a different port, then open that port on `127.0.0.1`. Stop the server with Ctrl-C. The server binds only to loopback, does not open the browser automatically, and serves no external resources. Requests and model calls stay local. The interface displays detected intent, support status, feature ID, whether a preview is available, the explicit no-action status, and registry-backed steps and limitations. It uses the same frozen matcher tested below: action recognition is not reliable, so do not infer that a preview authorizes an action. No app action can be executed by this prototype.

## Independent evaluation

`independent_cases.json` contains 72 new requests with no exact overlap with the development cases. `independent_results.json` records the initial run, including full previews and path-audit findings. `independent_eval.py` is retained as the historical runner and rejects changed rules by design. `safety_eval.py` runs the revised matcher on a specified labeled corpus and records current rule hashes. The previous initial results remain unchanged. Ollama predictions may vary; hashes do not freeze model inference or the source registries. See `TEST_RESULTS.md` for the initial results and important failure examples.

The revised 72-case regression and 62-case holdout are stored separately in `regression_results.json` and `holdout_results.json`. `holdout_rule_freeze.json` records the rule hashes created before the holdout cases. The holdout exposed incorrect matches and real-action requests that were only clarified, so its results must not be used to infer action authorization or device readiness. The original 72-case initial evaluation remains available in `independent_results.json`.

## Native Flutter development preview

The debug-only Flutter assistant connects to the separate authenticated, single-client development API. See [FLUTTER_IPHONE_SETUP.md](FLUTTER_IPHONE_SETUP.md) for LAN configuration, iOS permission, trust limitations and startup steps. The browser preview server remains loopback-only.
