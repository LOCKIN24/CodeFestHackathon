# Family outing contract

This extends the existing in-memory trusted-LAN demonstration relay. It coordinates a family's planned trip; it does not reserve stock, verify eligibility, or redeem a municipal benefit. Existing family credentials and revocation apply. Device polling remains the existing foreground polling mechanism.

Only the deliberately selected public store and planned meeting time are shared. Route endpoints, home/school coordinates, card numbers, student names, and photos are not accepted by these endpoints. Store names/addresses are display text selected by the parent, not verified store inventory.

## Read

`GET /v1/parent/children` with a parent bearer token and `GET /v1/child/profile` with a child bearer token retain their existing shapes. Child profiles optionally include:

```json
{
  "outing": {
    "week": "2026-11-02",
    "status": "planned",
    "revision": 2,
    "requestedAt": "2026-11-08T16:00:00+08:00",
    "updatedAt": "2026-11-08T16:01:00+08:00",
    "plannedAt": "2026-11-08T09:00:00+00:00",
    "store": {
      "name": "全家 示範門市",
      "address": "臺北市公開門市地址",
      "latitude": 25.03,
      "longitude": 121.56
    }
  }
}
```

The relay calculates the current Monday date using its Taipei clock. An absent/current-week-unavailable outing has revision **0**. Prior-week outings are omitted from all profile responses, with the prior object retained internally until the next mutation. `requestedAt` exists only after a child's request. `store` and `plannedAt` exist for planned/completed plans; cancellation clears both. Possible statuses: `requested`, `planned`, `canceled`, `completed`.

## Mutate

All requests are JSON objects with exactly the documented fields. All successful mutations return HTTP 200 `{ "child": <current profile> }`. Each successful state change advances the revision once. The caller must use the revision last observed for the current Taipei week.

Child bearer token:

- `POST /v1/child/outing {"action":"request","expectedRevision":0}`
- `POST /v1/child/outing {"action":"cancel","expectedRevision":2}`

Parent bearer token:

- `POST /v1/parent/outing {"childId":"<32 lowercase hex>","action":"plan","expectedRevision":1,"plannedAt":"2026-11-08T09:00:00Z","store":{"name":"全家 示範門市","latitude":25.03,"longitude":121.56,"address":"臺北市公開門市地址"}}`
- `POST /v1/parent/outing {"childId":"<32 lowercase hex>","action":"cancel","expectedRevision":2}`

A child can request from no current outing or a canceled outing. A parent can plan without a request, accept a request, revise an existing plan, or start after a cancellation. Both roles can cancel requested/planned outings. A repeated request cannot erase a current request/plan. A parent cannot request and a child cannot plan.

`plannedAt` must be a timezone-aware ISO 8601 UTC instant (`Z` or `+00:00`), strictly after the server clock and still within the current Taipei week. It is normalized to UTC seconds in responses. Store `name` is trimmed and 1–120 characters; optional `address` defaults to `""` and is at most 240 characters. Both reject control characters. Coordinates must be finite numeric values, latitude in [-90,90], longitude in [-180,180]; booleans are rejected. Unknown fields are rejected, including personal/route endpoint fields. Revision must be a nonnegative integer (not a boolean).

The request size limit remains 8192 bytes. Requests execute within the existing relay lock so racing revisions have one winner.

## Completion and recovery

An existing parent/child record for the current week prevents a new request/plan. Adding a same-week record marks a requested/planned outing `completed`, preserves its public store/time, and advances revision once. Duplicate record submissions do not repeatedly advance revision. The opt-in demo transaction endpoint follows the same completion behavior and retains `source: demo_transaction`; completion never means official verification.

Errors retain the existing JSON `{ "error": "<message>" }` shape:

- **400**: malformed/unknown fields, disallowed action for role, invalid revision/store/time.
- **401**: invalid/revoked credential or wrong endpoint credential role. Reconnect the device.
- **404**: parent selected a child outside its family.
- **409**: stale revision, conflicting active request, no cancelable outing, or an already-recorded current week. Refresh the profile and let the user review before retrying.

Do not automatically replay a failed mutation using a new revision. If a response is lost, reload to determine whether the mutation succeeded. Offline clients may display cached plans with an offline notice, but must not claim a new request/plan/cancellation was delivered.

## Verification

`python3 -m unittest discover -s tools/milk_demo_server -v` covers the existing family/redemption contracts plus authenticated outing request → parent plan → shared display → record completion, cancellations/replanning, racing revisions, malformed fields, date boundaries, week reset, sibling/family/role isolation and revocation. All are local-relay tests; no official service is called.
