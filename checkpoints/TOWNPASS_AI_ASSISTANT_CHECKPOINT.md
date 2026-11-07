# TownPass AI Assistant Local Checkpoint

Date: 2026-10-31

## Flutter app

- Repository: `TownPass/`
- Local commit: `d25c6a1` — `Checkpoint native AI assistant simulator integration`
- Branch: `main`
- Includes native assistant UI/client, Home entry point, Debug-only iOS local-network plist, and assistant tests.
- This commit is local only; it was not pushed.

## Navigation Lab

- Source directory: `tools/navigation_lab/`
- Archive: `checkpoints/townpass-navigation-lab-2026-10-31.tar.gz`
- SHA-256: `5092fc5e99d3e01b19944540eb807744c1e02daa772c969057800cdcf3a83325`
- Contains the Navigation Lab code, labeled/evaluation data, reports, tests, and launch/setup documentation. Python bytecode cache is excluded.
- The lab uses audited workspace registries under `docs/`; those registries were not modified or copied into this archive.

## Runtime secrets

The simulator API bearer token and Dart-defines file are intentionally excluded. They were kept in a private temporary directory and should be regenerated for a future run. Follow `tools/navigation_lab/FLUTTER_IPHONE_SETUP.md` to configure a fresh local token and start the API.
