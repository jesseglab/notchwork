# Your interface, Notchwork’s container

Notchwork owns the shared notch window and morphing container. Apps supply content and receive actions through the local API. Portkeeper uses this shared runtime for all notch UI. Native app windows remain owned by their app.

## Custom panels in the shared host

Publish a normal `NotchActivity` with an optional `interface`:

```swift
let card = NotchActivity(
    id: "service", sourceID: "com.example.app", sourceName: "My App",
    title: "Service ready", subtitle: "Custom controls available",
    ttl: 60,
    interface: ActivityInterface(
        html: """
        <style>
          body { font: 15px system-ui; background: #101b14; color: #dcffe5; padding: 24px }
          button { padding: 12px; background: #acffbf; color: #082213; border: 0; border-radius: 12px }
        </style>
        <h1>Your layout</h1>
        <button onclick="notchwork.invoke('restart', 'known-service-id')">Restart service</button>
        """,
        height: 240,
        actions: ["restart"]
    )
)
try await client.publish(card)
```

Register a new source with `SourceRegistration(id: "com.example.app", name: "My App", customInterface: true)` before publishing to enable its custom interface on first connection. Registration preserves an existing user choice, including disabling Custom UI. An unregistered source defaults to the normal card. Disabling the source or its custom-interface permission removes the embedded page. Source IDs still use the existing shared-token trust model; they are not verified identities. Enable custom UI only for trusted integrations.

The page receives `window.notchwork.invoke(action, value)`, where both arguments are strings. Only declared action names and values up to 2 MiB are accepted. The host attaches source ID, activity ID, sequence, and timestamp; page code cannot override them. The host does not execute the requested function itself.

Your running app retrieves events and performs only actions it recognizes. Use `wait: true` in a cancellable loop: the host waits up to four seconds and responds immediately on interaction, keeping idle traffic low.

```swift
let events = try await client.events(sourceID: "com.example.app", after: lastHandledSequence, wait: true)
for event in events {
    guard event.activityID == "service", event.action == "restart",
          event.value == "known-service-id" else { continue }
    // Call your own service controller here, after checking its current state.
    lastHandledSequence = event.sequence
}
```

Advance the cursor after handling or deliberately rejecting every event. Passing `after` acknowledges earlier events for that source. Delivery is not exactly-once: use the sequence to avoid handling a repeated event, and make consequential actions idempotent where possible. Store the cursor alongside the connection token; reset it when a restarted host changes the token. The queue retains events for 30 seconds, with at most 64 pending per source and 256 total. Publishing/removing activities does not execute actions.

Events are transient, not a durable job queue. An offline app cannot act; its activity should expire promptly. Keep the command handler in your app and validate identifiers against its own current state. Never treat an event value as a shell command. Portkeeper's bridge accepts only known service IDs, known projects, and a fixed list of operations.

## Icons, layout, and lifecycle

- `iconPNG`: optional base64 PNG for the compact slot and fallback card, up to 128 × 128 pixels and 16 KiB of base64. Icons are cached; no animated image decoding is supported.
- `interface.html`: up to 64 KiB of UTF-8 HTML, including styles/scripts. Escape app data inserted into HTML or JavaScript. Never include secrets.
- `interface.height`: 80–800 points. In a single-app presentation, the host sizes the expanded container to this content height, bounded by the display.
- `interface.width`: optional preferred content width, 240–1000 points (400 by default). A permitted single-app interface fills the container below a small settings/collapse toolbar, without the generic card heading or footer. Shared slots still require responsive layout.
- `interface.stateJSON`: optional valid JSON encoded as a string, up to 2 MiB UTF-8. Requires runtime build 8 or newer; verify `ping.capabilities` contains `interface-state`. Keep HTML stable and publish changing model data here. Read `notchwork.state` on load and listen for `window` events named `notchwork:state`; `event.detail` is the decoded JSON. State is delivered after load and on changes without replacing the document, preserving input focus and page state. Missing state is delivered as `null`.
- `interface.actions`: up to 20 unique names, each using letters, digits, dots, underscores, and hyphens.
- The complete JSON request must still fit the API's 16 MiB body limit.
- Updating HTML reloads the document. Keep it unchanged when possible to preserve text inputs and local view state; use `stateJSON` for changing model data.
- The host uses a nonpersistent WebKit data store. Its content security policy blocks normal network/resource loading except embedded data images/fonts, and navigation to external pages is denied. The page receives no connection token or local file access from the bridge. Browser dialogs are suppressed.
- This is an interface for trusted local integrations, not a general-purpose browser or a security guarantee for hostile JavaScript. Avoid continuous work, expensive effects, and large data assets. Honor `prefers-reduced-motion`.
- When the expanded surface detaches from its window, the document is cleared so scripts and timers stop. Reopening reloads it. Keep sustained native terminal rendering in your app’s ordinary windows.

The host settings/collapse toolbar, source permissions, slot assignment, and priority rules remain controlled by the user. App styling applies within its panel; it cannot replace the host settings or another app's slot policy.

If Custom UI is disabled for an existing source, the host explains why it is showing a fallback and offers an explicit user action to enable app controls. Registration never changes that saved choice.

## Forms and multi-page interfaces (build 9+)

Require `ping.capabilities` to include `interface-forms` before using the expanded limits. HTML remains a stable document (64 KiB maximum); state and each event value may be up to 2 MiB. Total live state and queued event values each have an 8 MiB host budget. The HTTP body is bounded at 16 MiB to allow JSON escaping; headers remain below 4 KiB. Prefer small updates.

Hosts with `user-controlled-pinning` (0.2.1/build 10+) collapse when the pointer leaves, including editor, review, and output pages. Only an explicit user pin in the toolbar keeps the container open. The legacy `interface.keepOpen` field remains decodable but is ignored; do not rely on it. Escape and the close button always collapse and clear the pin. Background updates never present. Save drafts in your app, give each page a fresh token, reject events from old tokens, and validate submissions in the app. Include draft fields with button events so fast typing followed by Save cannot lose the latest text. Keep HTML stable when resizing or changing pages.

User-requested editors may include the specific command/configuration being edited, and output pages may include selected local output. Keep this data out of generic summaries, external resources, diagnostics, fixtures, and logs. The host receives it in memory only and grants no execution capability to the page. Your app handles native file pickers, clipboard operations, validation, confirmations, and execution; the host has no app-specific knowledge.

[Forms payload example](../Examples/forms.json) supplies a stable document and a token-bearing Save event. Pair it with your own event consumer; the host does not save anything itself.
