# Application map coverage

Status: **COMPLETE** for the bounded source-level audit. Counts reflect the current documentation and checked-out source. Candidate records are review leads, not unique UI controls or edges. Five physical iPhone flows are owner-reported in `NAVIGATION_TEST_PLAN.md`; they were not observed in this audit. Programmatic navigation remains unverified.

| Measure | Current count / scope |
|---|---|
| Registered route records | 76: 21 Flutter and 55 Vue, including nine componentless Vue parents. |
| Final route audit | 76/76 source-reviewed: 55 Vue and 21 Flutter records. |
| Indexed route-bearing screens | 67: 21 Flutter and 46 Vue; four additional main tabs are non-route screens. |
| Feature registry | 27 entries; 27 have source relationship audits and received the final consistency check. No AI actions enabled. |
| Source-reviewed control records | 338 structured records, including reusable templates and context-specific instances; not the number of candidate lines. |
| Source-backed navigation edges | 185 structured edges, including conditional and dynamic destinations; runtime success is not established. WebView history-back and close are recorded as history-dependent and navigator-pop edges. |
| Reviewed non-route states | 46 state records; semantic transition audit 46/46. |
| Semantic navigation edge audit | 185/185 reviewed with evidence and status; 0 remain pending. |
| Audit queue | 382 candidates: 358 source-reviewed, 14 false positives, 10 duplicates, 0 unresolvable, 0 pending. |
| Pending by candidate type | 0 control, 0 navigation, 0 modal. |
| Explicitly unimplemented control records | 16; this is a count of explicitly classified records, not a claim about every possible no-op. |
| Owner-reported physical flows | 5; device model, OS version, app revision and date not supplied. |

The candidate queue, bounded 14-group missing-control checklist, and source-level consistency review are complete. The map records conditional and dynamic behavior; registered routes, success messages, and source-reviewed paths do not prove runtime reachability or successful transactions. The five owner-reported iPhone flows remain separate from source verification. Validation checks references and audit coverage, not runtime behavior.

## Final feature relationship audit

Each row has source-backed paths, controls, edges, dependencies and explicit limitations. This is not runtime verification.

| Feature ID | Final audit | Remaining issue |
|---|---|---|
| `home` | Source reviewed | City news callback is empty; Activity list or banner arguments can be null during loading despite typed destination requirements |
| `services` | Source reviewed | Four official-service cards have TODO-only callbacks; several catalog destinations are empty; Save in editor retains in-memory pin state without observed persistence |
| `perks` | Source reviewed | Store/use confirmation handlers show success states without establishing wallet mutation or real redemption; Payment confirmation leads to completion UI without evidence of real payment |
| `bills` | Source reviewed | 設定 and 新增綁定 callbacks are empty; 發票 and 收據 have no callbacks; Reviewed fee payment confirmation only routes to a completion UI; no real transaction established |
| `account` | Source reviewed | Account history/authorization and subscription callbacks are empty; Account data is mock; no real login established |
| `language_settings` | Source reviewed | Selection callback is empty; locale and preference are not changed; Runtime and accessibility remain unverified |
| `settings` | Source reviewed | Notification and quick-login switches change only local widget state in inspected code; History tile and logout have no action callback |
| `activity_information` | Source reviewed | More and loading-placeholder banner callbacks can pass null while destinations expect typed values; Failure and image/network behavior require runtime verification |
| `municipal_applications` | Source reviewed | Form preview submit logs data and shows completion dialog; fetch example is commented; Bridge user identity and real submission are unverified |
| `library_services` | Source reviewed | Local reservation success does not prove a live library transaction; Geolocation, map configuration, empty or invalid IDs and deployment behavior need runtime verification |
| `messages` | Source reviewed | Trash callback empty; 全部已讀 is display text with unread count, no tap handler in list source |
| `personal_information` | Source reviewed | Updates are local mock account changes; no remote update in inspected service; Editor return uses navigator pop; runtime validation and persistence unverified |
| `feedback` | Source reviewed | sendFeedback is empty; 有話要說 tap recognizer is empty |
| `startup_page` | Source reviewed | Persistence and next-launch behavior not tested on device; Changing preference is not itself a tab-navigation action |
| `invoice_receipt` | Source reviewed | View contains placeholder privacy-statement text and no carrier-entry or binding control; Default app-bar back is inherited; route and device behavior unverified |
| `online_police` | Source reviewed | No phone call or report was performed; Web page content and any actual submission require separate verification |
| `qr_scan` | Source reviewed | Null or cancelled image selection shows recognition error; stack pop destination depends on navigator; No real scan or permission prompt tested in this review |
| `service_catalog` | Source reviewed | Save toggles editing off but no durable persistence is established; cancel restores recorded snapshot where possible; Several catalog items have empty destinations |
| `citizen_report` | Source reviewed | Form checks local fields and shows receipt dialog without a submission request in inspected handler; Search detail logs route ID but displays same mock detail regardless |
| `disaster_report` | Source reviewed | Submit validates local fields, logs the form and opens success dialog; no real submission established; Direct form entry can lack initialized store data |
| `counter_calling` | Source reviewed | No real counter reservation or live wait-time integration established; Fax is a same-route link without explicit params; runtime route resolution unverified |
| `subscription` | Source reviewed | Vue subscription API example is commented; localStorage update does not prove backend subscription; Flutter and Vue subscription states are separate implementations |
| `surrounding_services` | Source reviewed | Fetch errors return empty results; map loading and permission behavior remain runtime-unverified; No authenticated or production service capability established |
| `police_report` | Source reviewed | Form handlers log local data and show success dialog; real police submission is not established; Direct record detail may have empty store; runtime behavior not verified |
| `faq` | Source reviewed | Account 功能教學 points to id.taipei external FAQ, not established as the local Vue /qna route; Normal entry and direct navigation remain unverified |
| `ticket_wallet` | Source reviewed | Displayed QR code and mock wallet are not evidence of real issuance or redemption; Missing exchange item causes no activeData view; direct navigation/runtime not verified |
| `fee_search` | Source reviewed | Blank search still runs name matching and can display all fees; Search and navigation are source-reviewed but deployed and device behavior are unverified |

## State and shared-context checkpoint

All 45 previously recorded states and the newly indexed attachment-size warning have source-backed semantic classifications. `BaseDialog` closes on its positive and negative buttons before emitting callbacks; its dialog close handler instead keeps the model open. The library ranking dialog still has no established opener. Reviewed shared contexts include nine `FixedTitleSection` parents, pinned services on the services tab and editor, coupon result items in list and hotspot views, and attachment/location components across citizen, disaster and police forms. The remaining shared contexts and bounded missing-control pass were subsequently completed as recorded below.

The targeted report-form inspection added the attachment file selector and size-error state. Disaster and police contexts enforce per-file thresholds; the citizen-report handler does not enforce the displayed aggregate 40 MB limit. The five owner-reported physical iPhone flows remain separate from source verification.

## Bounded shared-context and missing-control review, 2026-10-30

- `BaseDialog` (`TownPass-Services/src/components/atoms/BaseDialog.vue:19–36`): positive/negative actions close before forwarding events; the Headless UI close callback sets the model true. Its declared callers are represented among the previously reviewed state records; `LibraryNoticeDetailView.vue` imports it but has no declaration, so the import alone is excluded.
- `ServiceTabsView` and `ServiceTabs` (`TownPass-Services/src/components/organisms/ServiceTabsView.vue:19–31`, `TownPass-Services/src/components/molecules/ServiceTabs.vue:23–35`): the model forwards through the wrapper and button selection changes the displayed slot. The shared control now lists HomeView, CitizenReportView, CitizenReportSearchDetailView, PoliceReportRecordDetailView, CouponView, CouponDetail and TicketWallet. Wallet has two additional nested status-tab instances and resets status when its outer tab changes (`TicketWallet.vue:126,178,186,237`); these are context instances, not separate routes.
- `BaseMultipleSelect` and `ApplyServiceInfoForm` (`TownPass-Services/src/components/atoms/BaseMultipleSelect.vue:27–34,53–71`, `TownPass-Services/src/components/molecules/ApplyServiceInfoForm.vue:46–58,188–200`): confirm emits selected values and an opener callback; the parent's conditional 變更 control invokes the saved callback. The state registry now links both open paths and confirmation.
- `TPAppBar` (`TownPass/lib/util/tp_app_bar.dart:37–47`) forwards explicit leading and actions to Flutter `AppBar`. Checked home, services, perk, scanner and WebView explicit leading/action contexts, and the null-leading callers in the call-site list. Null leading delegates automatic behavior to Flutter; the subsequent app-bar audit records conditional inherited back controls and stack-dependent edges, without asserting the button is always visible.

Targeted missing-control categories checked so far: Flutter callbacks, GestureDetector, IconButton and popup/menu search in home, city service, account, settings, QR and message modules; Vue click/change/submit in coupon detail, citizen form, application preview and the shared tabs/multiple-select; dialog actions and dismissal for BaseDialog and the above components; conditional controls in those contexts; lifecycle navigation in library keyword search; bridge navigation for fee scan, QR return, WebView window-close and map calls. Source evidence includes `TownPass/lib/page/account/account_view.dart:38–91`, `TownPass/lib/page/qr_code_scan/qr_code_scan_view.dart:25–96`, `TownPass-Services/src/views/FeePaymentScanView.vue:18–68`, `TownPass/lib/util/web_message_handler/tp_web_message_handler.dart:267–280`, and `TownPass-Services/src/views/LibraryKeywordSearchView.vue:154`. Display-only labels and commented examples were excluded; callbacks already represented in the registries were not duplicated. No new control, edge or state was added in this execution. This was the initial partial pass; the finite checklist below records its completion.

## AppBar and remaining-module checkpoint, 2026-10-30

`TPAppBar` forwards its optional leading widget to Flutter `AppBar` without overriding `automaticallyImplyLeading` (`TownPass/lib/util/tp_app_bar.dart:19–39`). In the locally installed Flutter 3.47.8 source, that property defaults to true; an absent leading gives a drawer priority, otherwise a route implying app-bar dismissal gets a BackButton or, for a fullscreen dialog, CloseButton. Both use `Navigator.maybePop`, subject to route pop handling; local history can also imply dismissal. The SDK version actually used for a build was not established. Explicit leading controls, including the scanner and WebView, are not represented by this shared inferred control. Service editor's `PopScope` runs cancellation after a successful pop (`TownPass/lib/page/city_service_edit/city_service_edit_view.dart:20–26`). One shared control and 17 conditional, navigator-dependent edges represent the null-leading indexed route contexts; no fixed return screen is asserted.

The finite checklist is `MAP_REMAINING_MODULES.md`: 14 initially identified groups, 14 checked. The check added `agreement.consent_checkbox`, `disaster.search_text`, and `fees.result.bill_checkbox`; it also linked `citizen.category` to its disaster-report parent. The later review added report, library, fee and surrounding controls and two external-notice edges; findings and evidence are recorded in that file. The five owner-reported iPhone flows remain separate from source verification.

## Final consistency review

The final check compared feature screen/control memberships, navigation trigger contexts and destination IDs, route argument records and known nullability limits, state/control references and dialog dispositions, dynamic returns, bridge paths, and selected Mermaid diagrams with the structured graph. It corrected the scanner camera-result explanation and added the dynamic library notice anchors to the library diagram. `validate_map.py` checks these structural relationships, semantic-status evidence and the 14 terminal checklist rows; it does not prove behavior. No further actionable source-level work remains within this bounded audit.

Separately unresolved: runtime route resolution for `online_police` versus `/online_police` and counter fax parameter inheritance; nullable activity arguments; history and navigator pop outcomes; unestablished normal entries for portfolio and local Vue FAQ; hosted deployment equivalence; data-provided HTML links; device permissions, external services, and transaction outcomes. None has been tested or inferred as successful.
