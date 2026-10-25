# Integration lifecycle

[Quickstart](QUICKSTART.md) · [API](API.md) · [Custom controls](CUSTOM_INTERFACES.md)

## Ownership

Use one shared Notchwork runtime. Your app owns its content, action handlers, state, and ordinary windows. Never create a competing notch window or import a native surface into your app to duplicate the runtime. Legacy native primitives in the SDK are not the shared-runtime integration path.

## Connection sequence

```text
start app
  locate/install and launch the shared runtime
  discover connection.json
  ping → require apiVersion >= 2
  register source (declare customInterface if needed)
  publish current full activity
  consume events + refresh unchanged activity every 20 seconds
on disconnect / rotated token
  back off → rediscover → register → republish
on user opens notch
  publish latest state → present
on shutdown
  cancel work → remove own activity (TTL covers crashes)
```

The runtime generates a new token and an empty activity/event store after restart. Rebuild the client from the new connection file. Do not retry forever against a cached port/token. Use bounded backoff (for example 1, 2, then 5 seconds), cancel it on shutdown, and expose a useful connection state to users. Do not log credentials or echo the connection file in diagnostics.

Registration persists the source's display name and permissions. Initial registration may declare `customInterface: true`. Later registration preserves user restrictions. Do not change source IDs to bypass a disabled app or custom UI. Use one stable reverse-domain source ID and stable activity IDs.

## Update and attention rules

- Publish the **full activity**, not a patch. A raw JSON publisher must provide every required field in [the schema](command.schema.json). Swift's initializer supplies defaults.
- Use low for routine status, mid for meaningful progress/startup, high for issues requiring attention. Priority is relative display selection, not a system notification or permission to focus the app.
- Set TTL to 60 seconds and send an unchanged heartbeat every 20 seconds for a persistent card. TTL may be 2–3,600 seconds.
- Keep `notificationID` stable on heartbeats. Change it only for a genuinely new event with otherwise identical content.
- When an issue resolves, publish low, remove the activity, or allow expiry. A high-priority activity stays high until changed/removed/expired.
- One and Two obey user assignments. Multiple ranks high → mid → low, then newest meaningful change. One source takes at most one position.
- Call `present` only after an explicit user action. It temporarily opens that activity full-width and preserves the saved layout. Do not automatically reopen after reconnect.

## Custom controls

Supply offline HTML/CSS/JavaScript in `interface`, declare action names, and call `window.notchwork.invoke(action, value)` from a user interaction. Your app receives events and executes approved functions. Notchwork never executes your commands. Escape app data inserted in HTML; keep credentials out of generic summaries. A user-requested editor may display its own configuration; validate submitted edits in the app, never execute an arbitrary UI event as a command. External network resources and navigation are blocked.

Design responsively: each hovered side opens only that app’s full interface. One/Two/Multiple controls compact placement; expanded content uses the selected app’s requested dimensions, bounded by the screen. Support keyboard focus and reduced motion. Keep `interface.html` unchanged and publish live model data through optional `interface.stateJSON` (runtime build 8+). The page receives `notchwork:state` events without a document reload. Changing HTML still reloads the document and loses its local input state. Opening a detached/cleared page reloads it too. Persistent UI state belongs in your app. Pointer exit collapses even while editing unless the user has pinned the container; persist draft changes as they happen. Client `keepOpen` hints cannot override this.

## Event handling

Long-poll `events(sourceID:after:wait: true)` (up to four seconds). Keep a cursor for each source and host token. Ignore sequences already handled. Validate source, activity, action, and value against your own model. Advance the cursor after both handled and deliberately rejected events. Reset it only when the host token changes. Never interpret an arbitrary value as a shell command.

Delivery is **not exactly once**. For consequential operations, make handlers idempotent and keep an appropriate durable operation record in your own app. Events expire after 30 seconds and the queue is bounded; it is not a durable job queue. A reconnect alone cannot recover missed interactions. Keep one consumer per source to avoid competing acknowledgements.

## Validate before shipping

1. Run the app against a clean API 2 runtime and verify the card and a real action.
2. Exercise One, Two, and Multiple; confirm fixed assignments remain fixed.
3. Publish all three priorities; confirm unchanged heartbeats do not reorder peers.
4. Restart/quit the host, then relaunch it. Confirm reconnect without automatic presentation.
5. Disable the app and Custom UI; reconnect and confirm these choices remain disabled.
6. Kill your client and confirm TTL cleanup. Test normal shutdown cleanup separately.
7. Reject unknown actions, unknown object IDs, and stale events. Verify generic summaries and diagnostics exclude credentials and private output; only send selected content to explicit editor/output pages.
8. Test runtime missing, incompatible installation, signature failure, and concurrent installers if your app bundles the runtime.

[Portkeeper](https://github.com/jesseglab/portkeeper) demonstrates the app lifecycle and prerequisite installer. [The Python example](../Examples/interactive.py) demonstrates a small custom UI client.
