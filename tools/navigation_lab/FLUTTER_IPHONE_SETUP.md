# Native Flutter assistant: iPhone development setup

The center of the bottom navigation has an **AI 助理** launcher. It opens a native Flutter chat screen with source-backed previews. A narrow local allowlist automatically opens the registered language screen and, when its existing controller has loaded an ActivityList, the activity list; it does not perform payments, submissions, calls, account changes, or arbitrary web navigation. The matcher and Ollama remain on the Mac. The feature is for **debug development builds**; it does not enable HTTP access in Release or Profile builds.

## Requirements

- This workspace, Flutter/Xcode, an iPhone configured for development and signed with your Apple development team.
- Mac and iPhone on the same trusted Wi-Fi network. Find the Mac's Wi-Fi IPv4 address with `ipconfig getifaddr en0` (if your Wi-Fi interface differs, check Network settings). Find the iPhone's IPv4 address under Settings → Wi-Fi → the connected network's information button.
- Ollama running on the Mac at `127.0.0.1:11434` with the existing `gemma3:4b` model. Confirm with `ollama list` and `curl http://127.0.0.1:11434/api/tags`. No model is downloaded by the app. Set `NAV_LAB_MODEL=qwen3:4b` in the server environment to use the installed rollback model; the default is `gemma3:4b`.

## Start the API and app

In one terminal, from the workspace root, set the two addresses to the actual private IPv4 addresses for this session and generate a secret. These are placeholders, not production configuration:

```sh
cd /Users/quentinchih/Documents/hackathon
MAC_LAN_IP='192.168.1.20'      # replace with this Mac's address
IPHONE_LAN_IP='192.168.1.21'   # replace with this iPhone's address
export NAV_LAB_TOKEN="$(openssl rand -hex 32)"
python3 tools/navigation_lab/mobile_server.py --bind "$MAC_LAN_IP" --allow-client "$IPHONE_LAN_IP" --port 8766 &
NAV_LAB_PID=$!
```

The API binds only the specified numeric RFC1918/loopback address, requires a bearer token, rejects browser origins, and allows exactly the specified client IP. It exposes only the read-only `/api/mobile/preview` endpoint. It does **not** expose Ollama. Stop the API with `kill "$NAV_LAB_PID"` in that shell when finished. Address and token must be changed if the network/session changes.

In the same terminal, choose the device ID shown by `flutter devices`, and run:

```sh
cd /Users/quentinchih/Documents/hackathon/TownPass
flutter run --debug -d YOUR_IPHONE_DEVICE_ID \
  --dart-define="NAV_LAB_URL=http://$MAC_LAN_IP:8766" \
  --dart-define="NAV_LAB_TOKEN=$NAV_LAB_TOKEN"
```

For a simulator running on the same Mac, use `127.0.0.1` for both `--bind` and `--allow-client`, and set `NAV_LAB_URL=http://127.0.0.1:8766`. On an iPhone, `127.0.0.1` is the phone itself, not the Mac. An iPhone may show a local-network permission prompt; allow access for this development session. Debug builds use `Info-Debug.plist` with local-network usage text and ATS exceptions for loopback and RFC1918 address ranges. Release and Profile continue to use the original `Info.plist` and the client refuses the development endpoint outside debug mode.

**Trust boundary:** this development connection uses HTTP, so requests and the bearer token are not encrypted on the LAN. Use only a trusted private network and non-sensitive demo data; the IP allowlist is not cryptographic authentication. Dart defines are embedded in the debug build and may be visible in local process/build artifacts. Do not reuse the token or ship it. This is a preview prototype, not a production security design.

## Troubleshooting

- **Configuration message:** verify that both Dart defines are present, the URL is a numeric RFC1918 address with no path, and the token matches the API's environment variable.
- **Cannot connect / timeout:** verify both devices share Wi-Fi, the Mac firewall permits the Python process, the API is running on the Mac IP and port, and `--allow-client` matches the iPhone's current IP. Allow local-network access in iOS Settings if denied. The model can take time to load.
- **401/403:** check the matching token and the exact allowed client IP. Changing Wi-Fi or using a VPN can change the address.
- **Model unavailable:** start the existing Ollama server locally and verify the API with `curl`; the assistant will show a clarification/error rather than execute anything.
- **Unsupported or incomplete:** the model can misclassify requests; the audited graph has gaps, unverified prerequisites and typed arguments. A source preview is not proof of runtime reachability. Automatic navigation also requires a narrow Flutter-side whole-request check and runtime prerequisites; other destinations remain unavailable. See `TEST_RESULTS.md` for recorded false acceptances.
