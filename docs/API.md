# Local integration API

Notchwork speaks HTTP on an ephemeral IPv4 loopback port. Read `~/Library/Application Support/Notchwork/connection.json` while the host is running. It contains `endpoint` and `token`; rediscover them after each restart. Treat the token as private. The directory is mode 0700 and the connection file is mode 0600.

## Request

Send `POST /v1/activity` with `Authorization: Bearer <token>`, `Content-Type: application/json`, and Content-Length. The connection closes after one response. Chunked transfer and browser-origin requests are unsupported.

```json
{
  "operation": "publish",
  "activity": {
    "id": "build-main",
    "sourceID": "com.example.builder",
    "sourceName": "Builder",
    "title": "Building · 64%",
    "subtitle": "Debug · arm64",
    "symbol": "hammer.fill",
    "priority": "normal",
    "preferredSide": "left",
    "progress": 0.64,
    "details": ["12 of 19 targets complete"],
    "actions": [{"title": "Open dashboard", "url": "http://localhost:3000"}],
    "ttl": 60
  }
}
```

All activity fields shown are required in JSON except `progress`, which can be omitted or null. The Swift initializer supplies defaults. Symbols use SF Symbols names; unknown symbols fall back to the app symbol.

| Operation | Payload | Effect |
| --- | --- | --- |
| `publish` | `activity` | Add or update a card, preserving its queue position and refreshing expiry. |
| `remove` | `sourceID`, `id` | Remove one card. Removing an absent card is harmless. |
| `ping` | No other fields | Check the host connection. |

Update when app state changes. Refresh before `ttl` expires for long-lived activity, and remove a card when its job ends. Activity data is not persisted across host restarts. Layout assignments are persisted. Each new source is visible by default; priority permission defaults off.

## Priority and placement

Automatic slots follow `preferredSide`. A pinned slot can show its assigned source regardless of preferred side. Within a side, the same activity appears only once. A source can be explicitly assigned on both sides.

With source and slot permission enabled, `urgent` outranks `important`; equal priority retains arrival order. Removal or expiry restores the underlying activity. Priority does not open a panel or steal focus. Drawers show live matching cards ordered by their requested priority.

## Limits

| Field or resource | Limit |
| --- | --- |
| IDs | 1–128 bytes; ASCII letters, digits, dots, underscores, hyphens |
| Source name / title / subtitle | 60 / 120 / 240 characters |
| Symbol | 80 characters |
| Details | 30 lines, up to 500 characters each |
| Actions | 3; titles up to 40 characters; URLs up to 2,048 characters |
| Progress | 0 through 1 |
| Lifetime | 2–3,600 seconds |
| HTTP body / headers | 64 KiB / less than 4 KiB |
| Connections | 8 simultaneous, with a 5-second deadline |
| Live activities / registered sources | 128 / 32 |

Actions allow http(s) URLs with a host and without embedded credentials. They open only after a user clicks. The host does not execute commands, render HTML, or run uploaded code.

## Responses

```json
{"ok":true,"message":"Activity accepted."}
```

200 indicates success; 400 indicates malformed or invalid data; 401 indicates invalid authentication; 403 indicates an unsupported browser-origin request; 404 indicates an unsupported route; 413 indicates excessive request size. Malformed or overlong headers may close the connection without a JSON response.

## Trust boundary

A token authorizes access to the whole host. Source IDs are not authenticated identities: a trusted integration with the token can update or remove another source's activities. This version does not offer per-app credentials or revocation. Restarting rotates the token.

Sandboxed apps need a permitted way to obtain the connection information and connect to localhost. Automatic sandbox pairing is not implemented. See [SECURITY.md](../SECURITY.md).

## Examples

- [Swift activity client](../Examples/NativeIntegration.swift)
- [Python HTTP publisher](../Examples/publish.py)
- [Complete JSON card](../Examples/build.json)
- [Embedded custom SwiftUI surface](../Examples/EmbeddedSurface.swift)

## App-designed interfaces and events

Activities may include optional `iconPNG` and `interface` fields. Missing fields remain backward-compatible. See [custom interfaces](CUSTOM_INTERFACES.md) for validation limits, permission, lifecycle, and the page bridge.

```json
{"operation":"events","sourceID":"com.example.app","after":0}
```

The normal `{ "ok": true, "message": "UI events." }` response also includes an `events` array. Each event has `sequence` (unsigned integer), `sourceID`, `activityID`, `action`, `value` (string), and `createdAt` (Unix seconds). `after` acknowledges earlier events from that source and returns later ones. Events expire after 30 seconds. Only UI interactions inside a permitted, still-live activity create events; the public API has no operation for invoking callbacks or running commands. The shared host token still grants whole-host access, including event retrieval for sources; this is not per-app authentication.

Set `"wait": true` on an events request to hold it for up to four seconds until an interaction arrives. Other API requests continue independently. The Swift client exposes this as `events(sourceID:after:wait:)`. Waiting avoids frequent idle polls and delivers UI actions as soon as they arrive.
