# Quickstart

[Developer home](../README.md) · [LLM prompts](LLM_PROMPTS.md) · [Troubleshooting](TROUBLESHOOTING.md)

## 1. Start the shared runtime

Use macOS 14 or newer with Xcode command-line tools (`xcode-select --install` if missing). Python examples require Python 3.9+. Clone and build:

```sh
git clone https://github.com/jesseglab/notchwork.git
cd notchwork
zsh build.sh
open dist/Notchwork.app
python3 scripts/doctor.py
```

Success: `Connected to Notchwork API 2.` Startup is asynchronous; retry the doctor if the app is still launching. If an older Notchwork is running, quit it before opening this build. The menu-bar icon opens settings; no dashboard opens at startup.

This builds the current development code. It does not replace an installed app. Do not download an older release expecting API 2. Your app should pin a tested source commit when distributing.

## 2. Publish a card

```sh
python3 Examples/publish.py Examples/build.json --present
```

Success: the shared container opens with the build card. The Python example registers the source, publishes all required fields, and explicitly requests presentation because you passed `--present`.

Without `--present`, the card updates quietly. In settings, select the example in One mode, or choose Multiple. A successfully published card may remain hidden if another app is assigned. That is user policy, not a publication failure.

## 3. Send actions back to your app

```sh
python3 Examples/interactive.py --present
```

Click **Acknowledge**. The Python process logs the acknowledgement and changes the title. It runs for 60 seconds and removes its card on exit; use `--duration 120` for longer. Restart Notchwork while the example runs: it rediscovers the token, registers, and republishes. A blocked custom interface stays blocked after reconnect.

## 4. Run the Swift sample

```sh
swift run --package-path Examples/HelloNotch HelloNotch --present
```

The sample uses this checkout's SDK. It publishes for 10 seconds and removes the card. Abrupt termination is covered by its 30-second TTL. See [the sample README](../Examples/HelloNotch/README.md).

## Add to a Swift app

Add this dependency to `Package.swift` for initial development:

```swift
.package(url: "https://github.com/jesseglab/notchwork.git", branch: "main")
```

Add the product to your target:

```swift
.product(name: "NotchworkKit", package: "notchwork")
```

For a reproducible shipping build, replace `branch: "main"` with `revision: "YOUR_TESTED_40_CHARACTER_COMMIT"`. API 2 is not available on the old 0.1.x release tags. This links the client and shared types, not a running notch window; [bundle or require the runtime](DISTRIBUTION.md) separately.

```swift
import NotchworkKit

let client = try NotchworkClient()
let health = try await client.ping()
guard (health.apiVersion ?? 0) >= 2 else {
    throw ActivityError.invalid("Please update Notchwork to an API 2 runtime.")
}
try await client.register(.init(id: "com.example.myapp", name: "My App"))
let card = NotchActivity(id: "status", sourceID: "com.example.myapp",
                         sourceName: "My App", title: "Ready", priority: .low, ttl: 60)
try await client.publish(card)
// On a user click only:
try await client.present(sourceID: card.sourceID, id: card.id)
// On normal shutdown:
try await client.remove(sourceID: card.sourceID, id: card.id)
```

A real app also needs heartbeat, reconnect, and event handling. Follow the [lifecycle guide](DEVELOPERS.md), or start from [Portkeeper's bridge](https://github.com/jesseglab/portkeeper/blob/main/Sources/NotchworkBridge.swift).

## Use any language

Read `~/Library/Application Support/Notchwork/connection.json`, then send JSON with a bearer token to its loopback endpoint plus `/v1/activity`. Do not print the token, follow redirects, or route requests through a proxy. [The Python reference client](../Examples/notchwork_client.py) shows discovery and transport without external dependencies.

Use the [command schema](command.schema.json) for autocomplete and request validation. It describes request shape; the host is authoritative for byte limits and runtime rules. The [API reference](API.md) covers operations and responses.
