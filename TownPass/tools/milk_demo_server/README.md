# Family sharing and optional POS relay

The standard parent collection flow is **家庭設定 → 領取鮮奶**. It uses the local family POS provider: the same selected children, quota, history and passport update without a computer server. Duplicate-week submissions and repeated transaction IDs cannot add records. No government API is called.

## Cross-device family sharing

From the TownPass directory:

```sh
python3 tools/milk_demo_server/server.py --host 127.0.0.1 --port 8769 --enable-demo-transactions
```

`127.0.0.1` is suitable for simulators on this Mac. Real phones must reach the computer's private Wi-Fi IPv4 address; bind that address and configure it under **進階連線設定**, or supply `--dart-define=MILK_DEMO_SERVER=http://PRIVATE_IP:8769` at build time. Devices and relay must be on the same trusted network. The temporary HTTP relay is not intended for public exposure; restart clears its in-memory sessions.

1. The parent selects a child and creates a one-use invitation under **邀請孩子**.
2. The child enters through **開始設定 → 我是孩子，輸入邀請碼**, then scans the QR or enters the code. Codes are valid for up to ten minutes.
3. Foreground screens synchronize family records/outings. Removing a link invalidates its child credentials.

Printed card numbers, schools and photos are not sent to the relay. The chosen public outing store/time and sanitized pickup records are intentionally shared between linked devices. This remains a hackathon service simulation, not an official entitlement or redemption integration.

## Optional isolated transports

Developer/test flows may use `MilkRedemptionDemo.open('local')` for a separate persisted fictional family, or an explicit HTTP URL plus the opt-in `/v1/demo/families` and `/v1/demo/transactions` endpoints. These isolated transports do not replace normal family state. The explicit `openFamily()` mode is different: it commits a simulated POS event into the current parent's existing local family. There is no silent HTTP-to-local fallback after an uncertain request.

Operator settings retain replay, source connection and rebuild controls where applicable. Rebuilding an isolated fixture does not reset ordinary family data. For schemas and concurrency behavior, see [OUTING_API.md](OUTING_API.md).

## Checks

```sh
python3 -m unittest discover -s tools/milk_demo_server -v
flutter test
```

Live phone permissions, public networking, real EasyCard integration and actual government eligibility are outside the relay's scope.
