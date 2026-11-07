# Local intent matching results

Run on 2026-10-31 using the installed Ollama `qwen3:4b` and 4,096-token context. All 109 local model calls completed; 13 deterministic tests passed. The model proposals were captured once, then the final hybrid rules were reapplied to those exact responses after fixes discovered during evaluation, including the singular English “activity”. The chat was also smoke-tested with the final implementation. See `evaluation_results.json` for each label, proposal, decision and preview status, and `evaluation_summary.json` for counts and errors.

The 86 new cases are separate from the original 23, but both informed development of the rules. They are not a holdout set and these results do not establish broad accuracy or safety. The labels and sample mix are hand-authored for this prototype. Model output may vary on another run.

| Corpus | Cases | Model-only ID or null | Baseline ID or null | Hybrid ID or null |
|---|---:|---:|---:|---:|
| Original | 23 | 15 | 20 | 23 |
| Additional | 86 | 55 | 55 | 86 |
| Combined | 109 | 70 | 75 | 109 |

These figures count an expected null as correct for action, ambiguous and unsupported requests. The model-only and baseline columns are raw feature proposals and do not apply the hybrid intent guard, so the combined figures measure the complete hybrid policy against two feature matchers, not three equivalent intent classifiers. The original report's 17/23 model number used an earlier run and different labels for two action requests; the values above are from this run with action requests labeled null.

On the 73 supported viewing or detail requests alone, the model identified 70, the baseline 49 and the hybrid 73. The hybrid therefore performed better on this development corpus than both individual methods, but this is not evidence that it will generalize. For example, the model chose `account` for account settings; the hybrid resolved the compound to `settings`. The baseline missed QR scanning, while the model-backed hybrid matched it. The model and baseline both found the audited fee-search feature for fewer phrasings; the lab's `繳費項目` synonym resolves one such case.

Across all 109 cases, the final hybrid had **zero incorrect accepted feature matches**, rejected all 20 labeled action requests, and clarified all 16 unsupported or ambiguous requests. It falsely rejected zero of the 73 labeled legitimate viewing/detail requests. Six supported requests were clarified because they asked for an individual activity or message without its typed item; these were not counted as false rejections. These are results on the labeled corpus only; the wording rules can still miss actions, reject legitimate paraphrases, or accept an unsupported request that mentions a known feature.

Preview outcomes were 31 source-backed `preview`, 36 `incomplete`, 22 `clarify`, and 20 `rejected`. An incomplete result includes typed arguments or gaps in the audited graph, and a preview still has unverified prerequisites. For example, viewing payment history reaches only the recorded `bills.history` WebView boundary. Activity lists and details require `ActivityList` and `ActivityItem` respectively; no values are fabricated. Source-backed previews are not evidence of device reachability, live services or successful app behavior.

## Independent evaluation — frozen matcher

A separate set of 72 newly written requests had no exact text overlap with the 109 development cases. The existing matcher, simulator and model client were frozen by SHA-256 before the initial run; they were not tuned on these results. `independent_results.json` stores the hashes, labels, full decisions, previews and structural path checks. This is a small hand-labeled evaluation, and paraphrased concepts overlap with development examples; it is not a representative production sample. The labels were authored during the same development session.

| Initial outcome | Cases |
|---|---:|
| Correct accepted feature matches | 32 |
| Correct clarifications | 19 |
| Correct rejections | 2 |
| Incorrect accepted matches | 4 |
| Incorrect clarifications or rejections | 15 |

A view request counted as correctly accepted only when its feature ID matched and its preview was `preview` or `incomplete`. An item-detail request counted as a correct clarification when the intended feature was identified and missing data stopped the preview. A detail request that asked for clarification without identifying the intended feature was counted as incorrect; this conservative definition contributes two of the 15. For action requests, clarification was also counted as incorrect because the label required rejection, even though no action was executed.

Of 39 ordinary viewing requests, 32 were correctly accepted, six were incorrectly clarified and one was matched to the wrong feature. Six of eight item-detail requests were correctly identified and clarified. Of ten real-action requests, only two were explicitly rejected; seven were clarified and one mixed wallet-and-purchase request received an incomplete wallet preview. Of 15 unsupported or ambiguous requests, 13 were correctly clarified and two weather requests were incorrectly matched to Home. The remaining incorrect accepted match was a misspelled library request mapped to Account. These failures show the matcher is not ready to authorize real actions or device integration.

Preview statuses were 16 `preview`, 20 `incomplete`, 34 `clarify`, and 2 `rejected`. The structural checker found **zero unknown or mismatched recorded step/boundary IDs** in the returned previews. However, four cases received an unsupported or wrong-feature preview: the two weather/Home cases, the mixed wallet/purchase request, and the misspelled library/Account request. The first, second and fourth contained source-recorded steps to an inappropriate feature; the wallet result exposed a recorded boundary rather than a complete path. Thus no fabricated edge was detected by this check, but the system did suggest four inappropriate navigation previews. Structural checks do not prove intent correctness, dynamic parameter validity, complete graph coverage or runtime reachability.

The browser UI was tested with a source-backed language-settings preview and an explicitly rejected payment request. Separate HTTP checks covered an incomplete history boundary, ambiguous input, and loopback host/origin restrictions. No device integration or actual app action was attempted.

## Revised intent stage: regression and frozen holdout

The revised lab classifies intent before feature lookup and always sets `action_allowed` to false. It applies conservative deterministic checks and, for remaining browse requests, obtains a structured intent and feature proposal from local `qwen3:4b`. The audited feature ID is validated; disagreement or uncertainty is clarified. The model is never an authorization mechanism. The 72 previous independent cases became regression/development data for this iteration. The matching, preview and model-client files were then frozen by SHA-256 **before** creating the 62-request holdout, which has no exact text overlap with the prior corpora. The holdout evaluator checks the frozen hashes, and they were unchanged after the run. The holdout was hand-authored in the same project and is not representative of production traffic; no matching rules were tuned after examining it.

| Outcome | Regression: 72 | New holdout: 62 |
|---|---:|---:|
| Correct feature matches | 42 | 30 |
| Correct clarification or rejection of unsupported/ambiguous/action requests | 25 | 19 |
| Incorrect accepted matches | 0 | 3 |
| Incorrect clarifications or rejections | 5 | 10 |

These mutually exclusive outcomes count a supported specific-item request as a correct feature match when its feature is identified and the preview correctly stops for missing data: eight regression and five holdout matches were such detail requests. A labeled action counts as a correct rejection only if explicitly `rejected`; an action that is merely clarified is counted as incorrect. The holdout has 35 labeled view/detail requests, 12 action requests, eight unsupported requests, and seven ambiguous requests. One unsupported case records `home` in its expected-feature field as contextual wording; its `unsupported` category determines its expected outcome.

On the holdout, **five of 12 real-action requests were not explicitly rejected**. All five were clarified, and none was accepted for navigation: transfer money, close an account, complete a payment, erase messages, and ring the city office. Seven were explicitly rejected. Five of 35 legitimate view/detail requests were unnecessarily clarified or rejected. Examples include account settings, a typo in notifications, and a request to display a particular message. These figures do not establish real-world reliability or the safety of performing actions.

The three incorrect accepted holdout matches were air quality on Home → `home`, stock prices in Account → `account`, and a request for personal information **and** settings → `personal_information`. The first two are unsupported topics and the third is ambiguous. They show that a model and an exact feature name can still agree on the wrong scope. In the 72-case regression, all ten labeled real actions were rejected, no requests were incorrectly accepted, and five legitimate requests were unnecessarily clarified. That regression was used for development and is not a holdout.

Holdout preview outcomes were 11 `preview`, 17 `incomplete`, 27 `clarify`, and seven `rejected`. Four decisions were explicitly classified `unsupported`; other unsupported or ambiguous cases were clarified under ambiguity, and two unsupported topics were incorrectly accepted as noted above. The edge/control checker found zero mismatches among returned step and boundary IDs; this does not prove that a chosen feature is appropriate, that every possible route is present, or that runtime arguments and prerequisites are satisfied. Graph gaps across Flutter/WebView/Vue, typed `ActivityList`/`ActivityItem` and other runtime objects, conditional destinations, mock services, and unverified device reachability remain.

Fifteen deterministic tests passed. The local browser was exercised with a rejected mixed wallet/purchase request and an incomplete payment-history preview. Full per-case records, reasons, preview statuses, and rule hashes are in `regression_results.json` and `holdout_results.json`; `regression_summary.json` and `holdout_summary.json` contain the categorized counts. No model call failed in either run. The old 72-case initial results remain in `independent_results.json`. No real navigation or app action was performed; device integration is not recommended on these results.

## Demo-freeze verification

On 2026-10-31, the existing 72-case regression was rerun without changing case labels or the frozen matcher. It returned 42 correct feature matches, 15 correct clarifications, 10 correct rejections, and five unnecessary clarifications; no incorrect accepted matches or edge/control mismatches were detected. All ten labeled action requests were rejected, and all 72 returned decisions had `action_allowed: false`. Fifteen deterministic tests passed. The browser smoke test displayed a source-backed language-settings preview, an unsupported-topic clarification, and the missing `ActivityList` argument and dependencies. The new run is saved separately in `demo_regression_results.json` and `demo_regression_summary.json`; the earlier regression and holdout results remain unchanged. These results do not address the recorded holdout false acceptances or establish device readiness.
