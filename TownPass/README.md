# TownPass — integrated Studio build

Native Flutter app with the original assistant navigation, plus the completed milk-service experience:

- Weekly status, child switching, record/history controls and the separate trip tab.
- Family invitations, shared outings and school-to-home store search.
- The original offline 3D passport: upright cover, serif title, lower emblem, large lower actions and no decorative animation captions.
- Product-style local service flows for missing municipal APIs, persistent receipts/preferences, message actions, carrier storage and feedback.

Existing profiles/history are preserved. First use can seed fictional profiles only if no family state exists; `--dart-define=MILK_SHOWCASE=false` disables that seed. Local collection updates the selected family's same quota/passport records, with weekly duplicate protection and retry-safe event IDs. Isolated mock and HTTP transports remain separate operator options.

## Build

Use Flutter matching `.fvmrc` or a compatible SDK. Validation used Flutter 3.47.8 / Dart 3.13.7.

```sh
flutter pub get
dart run build_runner build
flutter test
flutter build ios --simulator --debug
```

Generated `.g.dart` / `.gen.dart` files and build caches are intentionally not committed. The passport HTML and its license are bundled under `assets/passport/`, so an ordinary Flutter build does not require Node or a server.

## Service configuration

Collection and local request/preference flows work without an external API. Map tiles, iOS native store search, external linked services and the existing assistant backend retain their network requirements. The iOS implementation includes native card OCR and store search; the Android host does not yet implement those two native channels.

Family sharing across devices uses the included LAN relay:

```sh
python3 tools/milk_demo_server/server.py --host 127.0.0.1 --port 8769 --enable-demo-transactions
```

For physical phones, bind the computer's private Wi-Fi IPv4 address instead. Configure that address in advanced connection settings or with `--dart-define=MILK_DEMO_SERVER=http://PRIVATE_IP:8769`. The relay is temporary and intended for a trusted LAN; restart invalidates its in-memory credentials. No credentials or student card numbers belong in source control.

The existing assistant's local backend workflow is documented in [`../tools/navigation_lab/README.md`](../tools/navigation_lab/README.md). This integration preserves its navigation, APIs and tests.

## Verification

```sh
flutter test
python3 -m unittest discover -s tools/milk_demo_server -v
```

The native passport integration check is separate:

```sh
flutter test integration_test/milk_passport_webview_test.dart -d SIMULATOR_ID
```

Prior Studio verification covered 132 focused app tests, 27 renderer tests, native iOS file-origin WebGL, family data consistency and mobile screenshots. Main integration validation passes all 151 Flutter tests (including the existing assistant suite and new combined-shell smoke test), all 31 relay tests, all 27 renderer tests, and the iOS simulator build. Physical-phone performance, real government submissions and complete English translation are not claimed. The iOS app identity/signing and Debug transport configuration are retained from this repository's main branch, not copied from a temporary preview or another developer's signing team.
