# Architecture

This describes the checked-out revisions listed in SETUP.md, not a production backend contract. Official overview: https://tpe-guideline.web.app/en/docs/.

## Flutter host

- `TownPass/lib/main.dart` initializes GetX services before `runApp`, requests notification permission and starts `GetMaterialApp` at `TPRoute.main`.
- `lib/util/tp_route.dart` defines GetX named routes and bindings. `MainView` uses an indexed stack and `lib/util/tp_bottom_navigation_factory.dart` supplies Service, Home, Perks and Bills tabs. Screens and controllers live in `lib/page/`; reusable widgets, theme and navigation are in `lib/util/`; typed data is in `lib/bean/`.
- `lib/service/` handles account, device/package info, location, local notifications, subscriptions and shared preferences. Account, home banners and activities read bundled `assets/mock_data` JSON; generated serialization and asset bindings come from build_runner. This is not evidence of a live municipal identity or production data backend.
- `lib/util/tp_web_view.dart` wraps `flutter_inappwebview`. Links in the city service catalog and other views mostly point at the hosted `taipei-pass-service.vercel.app`; the local Vue server is not automatically used.
- `ios/Runner/AppDelegate.swift` registers Flutter plugins and notification delegate; `ios/Runner/Info.plist` declares location, camera and photo-library usage. Plugins support location, notifications, image picking, scanning and URL launch. Physical hardware, authorization, and actual service outcomes were not verified.

## Vue services

One Vue 3.4.21 / Vite 5.2.8 application contains multiple service routes rather than separate independently running servers. `src/main.ts` installs Pinia 2.1.7 and Vue Router 4.3.0; `src/router/index.ts` uses HTML5 history, route metadata and view components. `src/views`, `src/components`, `src/stores`, `public` and `src/composables` contain pages, shared UI, state, data/assets and integration helpers. A production host needs history fallback for deep links. Many pages use bundled example data; some maps and location functions call external APIs. Examine each feature before treating it as real transactions.

## Web/native bridge

`TPInAppWebView` attaches the `flutterObject` WebMessageListener on creation. Vue `src/composables/useConnectionMessage.ts` posts a JSON string `{name, data}`; `useHandleConnectionData.ts` listens for message events and removes the listener on unmount. Flutter's `lib/util/web_message_handler/tp_web_message_listener.dart` decodes and dispatches by name to `tp_web_message_handler.dart`; replies are JSON strings `{name, data}` via the reply proxy. Existing names include `userinfo`, `location`, `deviceinfo`, `launch_map`, `phone_call`, `1999agree`, `open_link`, `notify`, and `qr_code_scan`. Some operations do not return a success reply. The host receives origin/frame information but the current dispatcher does not validate it; review allowed origins, frame and payload validation before exposing sensitive capabilities. Bridge behavior has been inspected, not tested end-to-end in this session.

## Future voice / on-device AI (design only)

Potential integration points: a Vue view and router entry for the service UI, a catalog entry in `lib/page/city_service/model/my_service_model.dart`, and an explicitly scoped bridge handler if native execution is needed. A Flutter service can own model lifecycle and permissions; platform-specific iOS work would likely touch `ios/Runner/AppDelegate.swift` or dedicated Swift code and `Info.plist` usage descriptions for microphone/speech as appropriate. An on-device model would need an evaluated runtime, model distribution, supported OS/device matrix, memory and storage budgets, privacy and permission design, and cancellation/error handling. No runtime, model or voice code is present or added by this preparation.
