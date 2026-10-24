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

The page receives `window.notchwork.invoke(action, value)`, where both arguments are strings. Only declared action names and values up to 4 KiB are accepted. The host attaches source ID, activity ID, sequence, and timestamp; page code cannot override them. The host does not execute the requested function itself.

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
- `interface.html`: up to 32 KiB of UTF-8 HTML, including styles/scripts. Escape app data inserted into HTML or JavaScript. Never include secrets.
- `interface.height`: 80–800 points. In a single-app presentation, the host sizes the expanded container to this content height, bounded by the display.
- `interface.width`: optional preferred content width, 240–1000 points (400 by default). A permitted single-app interface fills the container below a small settings/collapse toolbar, without the generic card heading or footer. Shared slots still require responsive layout.
- `interface.stateJSON`: optional valid JSON encoded as a string, up to 32 KiB UTF-8. Requires runtime build 8 or newer; verify `ping.capabilities` contains `interface-state`. Keep HTML stable and publish changing model data here. Read `notchwork.state` on load and listen for `window` events named `notchwork:state`; `event.detail` is the decoded JSON. State is delivered after load and on changes without replacing the document, preserving input focus and page state. Missing state is delivered as `null`.
- `interface.actions`: up to 20 unique names, each using letters, digits, dots, underscores, and hyphens.
- The complete JSON request must still fit the API's 64 KiB body limit.
- Updating HTML reloads the document. Keep it unchanged when possible to preserve text inputs and local view state; use `stateJSON` for changing model data.
- The host uses a nonpersistent WebKit data store. Its content security policy blocks normal network/resource loading except embedded data images/fonts, and navigation to external pages is denied. The page receives no connection token or local file access from the bridge. Browser dialogs are suppressed.
- This is an interface for trusted local integrations, not a general-purpose browser or a security guarantee for hostile JavaScript. Avoid continuous work, expensive effects, and large data assets. Honor `prefers-reduced-motion`.
- When the expanded surface detaches from its window, the document is cleared so scripts and timers stop. Reopening reloads it. Keep sustained native terminal rendering in your app’s ordinary windows.

The host settings/collapse toolbar, source permissions, slot assignment, and priority rules remain controlled by the user. App styling applies within its panel; it cannot replace the host settings or another app's slot policy.

If Custom UI is disabled for an existing source, the host explains why it is showing a fallback and offers an explicit user action to enable app controls. Registration never changes that saved choice.
