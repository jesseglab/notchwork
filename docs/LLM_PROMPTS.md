# Copyable LLM prompts

Use these with Codex, Claude, ChatGPT, or another coding assistant in your app repository. Choose one task, copy its whole block, and add your app-specific preferences. The prompts require the assistant to inspect the actual contract before implementing.

**Context:** [llms.txt](../llms.txt) is the short index. [llms-full.txt](../llms-full.txt) is a self-contained contract you can attach when the assistant cannot browse GitHub. These describe API 2 on the current development branch, not the old release tags.

## Integrate an existing Swift app

[Plain-text prompt](prompts/integrate-swift.txt)

```text
Read the current Notchwork developer contract before editing: https://github.com/jesseglab/notchwork/blob/main/llms-full.txt . If you cannot access it, ask me for that file; do not invent API methods or assume a 0.1.x release supports API 2. Inspect my repository and its instructions first.

Integrate Notchwork into this macOS Swift app. Derive a stable reverse-domain source ID from the app bundle ID. Identify the smallest useful status and existing controls to expose. Add NotchworkKit via SwiftPM at a tested commit supporting API 2, and keep ordinary app windows intact. Start with a status card; only use custom HTML if the existing controls require it. Follow docs/QUICKSTART.md and docs/DEVELOPERS.md. Keep connection work asynchronous and cancel it cleanly. Show an actionable unavailable-runtime state. If a prerequisite installer already exists, reuse it; otherwise document the runtime requirement rather than inventing a download URL.

Use one shared Notchwork background runtime. My app owns its content/actions; Notchwork owns all notch windows, morphing, placement, and settings. Require ping.apiVersion >= 2. Discover the current loopback connection without logging its token, register a stable source, publish complete payloads, and preserve user opt-outs. A 60-second TTL plus unchanged 20-second heartbeats is a reasonable starting point. Reconnect by rediscovering, registering, and republishing; do not automatically present on reconnect. Only call present for an explicit user action. Use low/mid/high appropriately and stable notification IDs on heartbeats.

Implement the change, add targeted tests, and document the integration. Report changed files, actual checks/results, and remaining limitations. Do not claim testing you did not run, do not publish a release unless asked, and do not change licensing.
```

## Integrate Python, Node, Rust, or another language

[Plain-text prompt](prompts/integrate-any-language.txt)

```text
Read the current Notchwork developer contract before editing: https://github.com/jesseglab/notchwork/blob/main/llms-full.txt . If you cannot access it, ask me for that file; do not invent API methods or assume a 0.1.x release supports API 2. Inspect my repository and its instructions first.

Integrate this app with Notchwork using its local HTTP JSON API in the app's existing language. Read docs/API.md and docs/command.schema.json, and use Examples/notchwork_client.py as a transport reference. Implement discovery of ~/Library/Application Support/Notchwork/connection.json, strict http://127.0.0.1:<port> endpoint validation, no redirects or proxies, bounded request timeouts, and explicit API error handling. Send POST /v1/activity with Authorization: Bearer and JSON. Include every required activity field; a publish request is a full replacement, not a patch. Do not expose the token to browser code. Prefer existing networking libraries and avoid adding dependencies solely for this small API.

Use one shared Notchwork background runtime. My app owns its content/actions; Notchwork owns all notch windows, morphing, placement, and settings. Require ping.apiVersion >= 2. Discover the current loopback connection without logging its token, register a stable source, publish complete payloads, and preserve user opt-outs. A 60-second TTL plus unchanged 20-second heartbeats is a reasonable starting point. Reconnect by rediscovering, registering, and republishing; do not automatically present on reconnect. Only call present for an explicit user action. Use low/mid/high appropriately and stable notification IDs on heartbeats.

Implement the change, add targeted tests, and document the integration. Report changed files, actual checks/results, and remaining limitations. Do not claim testing you did not run, do not publish a release unless asked, and do not change licensing.
```

## Build custom controls inside the container

[Plain-text prompt](prompts/custom-controls.txt)

```text
Read the current Notchwork developer contract before editing: https://github.com/jesseglab/notchwork/blob/main/llms-full.txt . If you cannot access it, ask me for that file; do not invent API methods or assume a 0.1.x release supports API 2. Inspect my repository and its instructions first.

Add an app-owned custom interface to this existing Notchwork integration. Read docs/CUSTOM_INTERFACES.md and Examples/interactive.py. Register customInterface: true for a new source; never bypass an existing opt-out. Provide responsive offline HTML/CSS/JavaScript with accessible focus and reduced-motion support, within the documented size/height/action limits. Escape model data and keep credentials, logs, and arbitrary commands out of the HTML. Declare a fixed action list and call window.notchwork.invoke(action, value) only on interaction.

Consume events with wait: true. Validate sourceID, activityID, action, and value against current app state. Keep one event consumer and a cursor per source/token, acknowledge deliberately rejected events too, deduplicate sequences, and reset only on token change. Make consequential handlers idempotent; delivery is not exactly once and events are transient. Keep persistent form state in the app and avoid reloading unchanged HTML. Demonstrate one real action round trip, not just a visual mock.

Use one shared Notchwork background runtime. My app owns its content/actions; Notchwork owns all notch windows, morphing, placement, and settings. Require ping.apiVersion >= 2. Discover the current loopback connection without logging its token, register a stable source, publish complete payloads, and preserve user opt-outs. A 60-second TTL plus unchanged 20-second heartbeats is a reasonable starting point. Reconnect by rediscovering, registering, and republishing; do not automatically present on reconnect. Only call present for an explicit user action. Use low/mid/high appropriately and stable notification IDs on heartbeats.

Implement the change, add targeted tests, and document the integration. Report changed files, actual checks/results, and remaining limitations. Do not claim testing you did not run, do not publish a release unless asked, and do not change licensing.
```

## Install Notchwork as an app prerequisite

[Plain-text prompt](prompts/bundle-runtime.txt)

```text
Read the current Notchwork developer contract before editing: https://github.com/jesseglab/notchwork/blob/main/llms-full.txt . If you cannot access it, ask me for that file; do not invent API methods or assume a 0.1.x release supports API 2. Inspect my repository and its instructions first.

Make Notchwork a required shared runtime for this macOS app. Read docs/DISTRIBUTION.md and inspect Portkeeper's Sources/NotchworkRuntime.swift and build.sh at https://github.com/jesseglab/portkeeper . Bundle a runtime built from the same tested commit as the SDK. Reuse a compatible verified user/system installation; otherwise stage, verify, and install the bundled copy into ~/Applications. Preserve incompatible destinations, handle concurrent installers, and clean failed staging copies. Launch without activation, detect an older running runtime, and wait for an API 2 handshake. Do not silently render a fallback notch.

Do not disable signatures, remove quarantine, download unpinned executable code, or claim ad-hoc builds are notarized. Document the product's signing policy and unresolved sandbox pairing needs. Include LICENSE and NOTICE; commercial use currently requires separate permission. Test missing/reused/incompatible/invalid bundles and first launch.

Use one shared Notchwork background runtime. My app owns its content/actions; Notchwork owns all notch windows, morphing, placement, and settings. Require ping.apiVersion >= 2. Discover the current loopback connection without logging its token, register a stable source, publish complete payloads, and preserve user opt-outs. A 60-second TTL plus unchanged 20-second heartbeats is a reasonable starting point. Reconnect by rediscovering, registering, and republishing; do not automatically present on reconnect. Only call present for an explicit user action. Use low/mid/high appropriately and stable notification IDs on heartbeats.

Implement the change, add targeted tests, and document the integration. Report changed files, actual checks/results, and remaining limitations. Do not claim testing you did not run, do not publish a release unless asked, and do not change licensing.
```

## Replace an app’s independent notch implementation

[Plain-text prompt](prompts/migrate-own-notch.txt)

```text
Read the current Notchwork developer contract before editing: https://github.com/jesseglab/notchwork/blob/main/llms-full.txt . If you cannot access it, ask me for that file; do not invent API methods or assume a 0.1.x release supports API 2. Inspect my repository and its instructions first.

Migrate this app's existing independent notch UI to the shared Notchwork runtime. First inventory all notch-specific windows, geometry, animation, hover/focus behavior, controls, and routes. Map each user action to an API-supplied card/custom control or an existing ordinary app window. Preserve service/business logic. Remove the duplicate notch renderer and any optional sharing/file-snapshot adapter once the direct API path works. Reuse the Portkeeper bridge/installer as a reference.

Explicitly report visual or feature differences; do not claim pixel parity unless verified. Test real controls, state updates, reconnect, permissions, cleanup, and that the app creates no independent notch windows. Keep Notchwork itself free of this app's adapters or domain logic.

Use one shared Notchwork background runtime. My app owns its content/actions; Notchwork owns all notch windows, morphing, placement, and settings. Require ping.apiVersion >= 2. Discover the current loopback connection without logging its token, register a stable source, publish complete payloads, and preserve user opt-outs. A 60-second TTL plus unchanged 20-second heartbeats is a reasonable starting point. Reconnect by rediscovering, registering, and republishing; do not automatically present on reconnect. Only call present for an explicit user action. Use low/mid/high appropriately and stable notification IDs on heartbeats.

Implement the change, add targeted tests, and document the integration. Report changed files, actual checks/results, and remaining limitations. Do not claim testing you did not run, do not publish a release unless asked, and do not change licensing.
```

