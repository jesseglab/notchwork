# Local integration API

[Quickstart](QUICKSTART.md) · [Lifecycle](DEVELOPERS.md) · [Request JSON Schema](command.schema.json) · [Copyable LLM prompts](LLM_PROMPTS.md)

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
    "priority": "mid",
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
| `publish` | `activity` | Add or update a card and refresh expiry. Meaningful changes advance its update order. |
| `remove` | `sourceID`, `id` | Remove one card. Removing an absent card is harmless. |
| `ping` | No other fields | Check the host; API 2 returns `apiVersion: 2`. |
| `events` | `sourceID`, optional `after` and `wait` | Retrieve/acknowledge transient UI events; long-poll with `wait: true`. |
| `register` | `registration: {id, name, customInterface}` | Register an app. New trusted clients may declare custom controls; existing user permissions are preserved. |
| `present` | `sourceID`, `id` | Explicitly open a live enabled activity in the shared container, without changing saved mode or assignments. |

Update when app state changes. Refresh before `ttl` expires for long-lived activity, and remove a card when its job ends. Activity data is not persisted across host restarts. Layout assignments are persisted. Each new source is enabled by default. Choose Multiple in settings to let notification priority decide placement.

## Priority and placement

The host has three modes:

- **One:** one selected app owns the full morphing container, including its custom controls. Other apps cannot interrupt it. Automatic chooses the oldest live app until it leaves.
- **Two:** one app stays on the left and one on the right. Explicit assignments override `preferredSide`; Automatic uses the preferred side and reserves the other side’s assigned app. Notifications do not replace fixed assignments.
- **Multiple:** all enabled apps compete for two visible positions across both sides. `high` outranks `mid`, which outranks `low`. At equal priority, the newest meaningful update wins. One app occupies at most one position. The expanded container shows the same selected apps as the compact notch.

The API accepts `low`, `mid`, and `high`, as well as legacy `normal`, `important`, and `urgent`. Swift clients can use `.low`, `.mid`, and `.high`. SDK encoding retains the legacy wire strings so existing hosts and snapshots remain compatible; `notificationLevel` provides the new display name.

A change to activity content or priority advances its update order. Republishing identical content, or changing only `ttl`, refreshes expiry without taking another app’s place. Optional `notificationID` (1–128 bytes) identifies a distinct event even when its text is unchanged. Use a new ID for a new notification and keep the same ID on heartbeats. Update IDs are opaque, not timestamps.

```json
{"notificationID":"build-42-failed","priority":"high"}
```

These are fields inside the existing activity payload; publish the full activity as above. To clear an alert, republish it with `low`, remove it, or let its `ttl` expire. On removal or expiry the next eligible app fills the position. Publishing priority never opens a panel or takes keyboard focus. `present` is a separate explicit-opening operation; clients must call it only in response to a user action. Closing the presentation restores the configured layout. Source Show and Custom UI permissions still apply. The legacy `SlotResolver` remains available to SDK clients; the simplified host uses `NotchLayoutResolver`.

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
| HTTP body / headers | 16 MiB / less than 4 KiB |
| Connections | 8 simultaneous, with a 5-second deadline |
| Live activities / registered sources | 128 / 32 |

Actions allow http(s) URLs with a host and without embedded credentials. They open only after a user clicks. The host does not execute commands from activities. App-supplied HTML panels require the separate Custom UI permission described below.

## Responses

```json
{"ok":true,"message":"Activity accepted."}
```

200 indicates success; 400 indicates malformed or invalid data; 401 indicates invalid authentication; 403 indicates an unsupported browser-origin request; 404 indicates an unsupported route; 413 indicates excessive request size. Malformed or overlong headers may close the connection without a JSON response.

## Trust boundary

A token authorizes access to the whole host. Source IDs are not authenticated identities: a trusted integration with the token can update or remove another source's activities. This version does not offer per-app credentials or revocation. Restarting rotates the token.

Sandboxed apps need a permitted way to obtain the connection information and connect to localhost. Automatic sandbox pairing is not implemented. See [SECURITY.md](../SECURITY.md).

## Examples

- [Runnable Swift package](../Examples/HelloNotch/README.md)
- [Swift activity snippet](../Examples/NativeIntegration.swift)
- [Python HTTP publisher](../Examples/publish.py)
- [Complete JSON card](../Examples/build.json)
- [Interactive custom UI with reconnect and cleanup](../Examples/interactive.py)
- [Runtime prerequisite packaging](DISTRIBUTION.md)

## App-designed interfaces and events

Activities may include optional `iconPNG` and `interface` fields. Missing fields remain backward-compatible. See [custom interfaces](CUSTOM_INTERFACES.md) for validation limits, permission, lifecycle, and the page bridge.

```json
{"operation":"events","sourceID":"com.example.app","after":0}
```

The normal `{ "ok": true, "message": "UI events." }` response also includes an `events` array. Each event has `sequence` (unsigned integer), `sourceID`, `activityID`, `action`, `value` (string), and `createdAt` (Unix seconds). `after` acknowledges earlier events from that source and returns later ones. Events expire after 30 seconds. Only UI interactions inside a permitted, still-live activity create events; the public API has no operation for invoking callbacks or running commands. The shared host token still grants whole-host access, including event retrieval for sources; this is not per-app authentication.

Set `"wait": true` on an events request to hold it for up to four seconds until an interaction arrives. Other API requests continue independently. The Swift client exposes this as `events(sourceID:after:wait:)`. Waiting avoids frequent idle polls and delivers UI actions as soon as they arrive.

## Runtime prerequisite and registration

The host contains no app-specific adapters or watched client files. A client installs/launches the shared runtime, discovers its current connection, and calls `register` before publishing its interface:

```json
{"operation":"register","registration":{"id":"com.example.app","name":"Example","customInterface":true}}
```

This authenticated request declares a trusted local client’s intent to render its own offline HTML controls. On initial registration it enables those controls; subsequent registrations cannot undo a user disabling the app or its custom UI. The same whole-host token trust model applies, with no claim of verified per-app identity.

The response includes `apiVersion: 2`. Re-register after host restart, then republish current state. Existing registered preferences persist; activity and event state do not.

```json
{"operation":"present","sourceID":"com.example.app","id":"status"}
```

`present` requires an enabled, unexpired published activity. It temporarily shows that activity full-width in the expanded container, even if the app is not assigned to a compact position. It never modifies saved assignments. Pure notification updates must use `publish` instead.

### App-sized live interfaces (runtime build 8+)

`interface.width` optionally requests 240–1000 points of content width; `height` sizes a single-app expanded container to its content. The host keeps its settings/collapse toolbar and display bounds. `interface.stateJSON` carries up to 2 MiB of valid JSON encoded as a string, delivered as `notchwork.state` and `notchwork:state` events without reloading unchanged HTML. The complete command remains limited to 16 MiB. Older API 2 hosts ignore these optional fields; clients depending on live state must ship/require build 8 or newer and check that `ping.capabilities` contains `interface-state`. The runtime also advertises `interface-size`. Missing capabilities mean unsupported, even if an updated app bundle exists on disk. See [custom interfaces](CUSTOM_INTERFACES.md).

Build 9 also advertises `interface-forms`: 64 KiB HTML, 2 MiB state and event values, 8 MiB aggregate state/queue budgets, and optional `interface.keepOpen` to suppress hover dismissal while editing. Manual collapse still works. See [form lifecycle](CUSTOM_INTERFACES.md#forms-and-multi-page-interfaces-build-9).
