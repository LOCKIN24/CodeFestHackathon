# TownPass setup (macOS)

Snapshot checked 2026-10-29: TownPass `e65b586771b67334e7a21c2aa9c6e80060e4f827`; TownPass-Services `3274852a94504b4fdaecc82ff3a9fda8342557f6`. These are separate repositories. Recheck their configuration if using newer revisions. Official guides: https://tpe-guideline.web.app/en/docs/flutter/home/project-setup.html and https://tpe-guideline.web.app/en/docs/micro-service/introductions/project-setup.html.

## Prerequisites

Install Xcode and its iOS simulator runtime, FVM, CocoaPods, Node and pnpm. Select Xcode with `xcode-select -p` and check `xcodebuild -version`, `fvm --version`, `pod --version`, `node --version`, and `pnpm --version`. This machine: Apple Silicon, macOS 27.0.1, Xcode 27.1, CocoaPods 1.17.0, FVM 4.3.2, Node 24.20.0. The globally installed Flutter 3.47.8 is **not** the version pinned by the app. Use FVM commands below; `.fvmrc` pins Flutter 3.47.6 (Dart 3.13.5). No Flutter or Node installation was needed on this machine.

```sh
git clone https://github.com/taipei-doit/TownPass.git
git clone https://github.com/taipei-doit/TownPass-Services.git
cd TownPass
fvm install
fvm flutter pub get
fvm dart run build_runner build
fvm flutter doctor -v
xcrun simctl list devices available
fvm flutter run -d <SIMULATOR_UDID>
```

The dependency install, generation and simulator debug launch succeeded here. `flutter run` automatically ran CocoaPods. Select an available simulator ID from the list. On Xcode 27, open Device Hub from Xcode > Open Developer Tool > Device Hub and select the booted simulator. The standalone Simulator app is no longer present. Home and all four tabs were visually checked in Device Hub; see KNOWN_ISSUES.md. Build files and FVM links are local artifacts; avoid committing machine-generated lockfile changes without review.

## Physical iPhone

Connect and unlock the iPhone, trust the Mac if asked, enable Developer Mode when prompted, and ensure Xcode shows it as available in Devices and Simulators. In `ios/Runner.xcworkspace`, choose Runner > Signing & Capabilities, select your own Apple team and a unique bundle identifier if required; let Xcode create appropriate local signing assets. Do not commit credentials, certificates, profiles or team-specific settings. Then use `fvm flutter devices` and `fvm flutter run -d <DEVICE_ID>`. Signing and device capabilities need their own verification; the simulator does not establish physical-device success.

## Vue services

The installed pnpm 12.14.0 rejected ignored build scripts. The following reproducible commands succeeded with pnpm 9.15.9 and the existing lockfile without changing global pnpm:

```sh
cd ../TownPass-Services
CI=true npx --yes pnpm@9.15.9 install --frozen-lockfile
npx --yes pnpm@9.15.9 dev --host 127.0.0.1
```

Open http://127.0.0.1:5173/ in a browser. `npx --yes pnpm@9.15.9 build` passed type checking and production build on this machine. Keep the dev server running in its terminal; Ctrl-C stops it. It listens only on the Mac's loopback address. A phone cannot reach the Mac through its own `localhost`. See INTEGRATION.md before testing Flutter against a local service. Do not add real API keys to source or commit them.
