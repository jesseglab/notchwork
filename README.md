# Notchwork

**One shared macOS notch. Your app supplies the content.**

Notchwork is a small background runtime with a morphing container, settings, and a local API. Connect from Swift, Python, Node, Rust, or any process that can send JSON over HTTP. Your app keeps its own logic and handles its own actions; Notchwork owns the notch window and animation.

**[Start here →](docs/QUICKSTART.md)** · **[Copy an LLM prompt →](docs/LLM_PROMPTS.md)** · [API reference](docs/API.md) · [Developer guide](docs/DEVELOPERS.md)

## See it working

Requires macOS 14+, Xcode command-line tools, and Python 3.9+ for the Python examples. From this repository:

```sh
zsh build.sh
open dist/Notchwork.app
python3 scripts/doctor.py
python3 Examples/publish.py Examples/build.json --present
```

If the runtime is still starting, run the doctor again. `--present` is your explicit request to open the example; normal background updates never open the notch. The card expires automatically.

Try [interactive controls](Examples/interactive.py):

```sh
python3 Examples/interactive.py --present
```

Click **Acknowledge** in the notch. The Python process receives the event, updates its own state, and republishes. Stop it with Ctrl-C, or restart Notchwork while it runs to see reconnection.

## Use Swift

```swift
import NotchworkKit

let client = try NotchworkClient()
let host = try await client.ping() // Require apiVersion >= 2.
try await client.register(.init(id: "com.example.app", name: "My App"))
try await client.publish(NotchActivity(
    id: "status", sourceID: "com.example.app", sourceName: "My App",
    title: "Ready", priority: .low, ttl: 60
))
```

[Run the complete Swift package](Examples/HelloNotch/README.md), or follow the [SwiftPM setup](docs/QUICKSTART.md#add-to-a-swift-app). The linked library is the API client; the shared runtime must also be running.

## What Notchwork owns

| Notchwork | Your app |
| --- | --- |
| One shared notch window and morphing | Content, branding, controls, and state |
| One / Two / Multiple placement | Low / mid / high updates |
| Expiry and connected-app settings | Heartbeats, reconnect, and cleanup |
| Offline HTML rendering and action delivery | Validation and execution of app actions |

**One** gives a selected app the whole container. **Two** fixes an app on each side. **Multiple** shows the two highest-priority apps, with newest meaningful updates breaking ties. Identical heartbeats do not change order. Users control placement and whether each app and its custom UI are enabled.

The collapsed container follows the physical camera notch: a 2-point edge when idle, or 36 points per side for small app icons while active. Titles and controls appear when expanded. Displays without a camera notch use a 72 × 28-point handle.

There are no built-in Music, Spotify, or Portkeeper adapters. [Portkeeper](https://github.com/jesseglab/portkeeper) is the reference client: it installs/reuses Notchwork and uses the API for all notch UI. Other clients can do the same. See [bundling the runtime](docs/DISTRIBUTION.md).

## Developer toolbox

| Need | Start here |
| --- | --- |
| First working integration | [Quickstart](docs/QUICKSTART.md) |
| Have an LLM implement it | [Copyable task prompts](docs/LLM_PROMPTS.md) / [plain-text context](llms.txt) |
| Know exactly what to send | [API](docs/API.md) / [JSON Schema](docs/command.schema.json) |
| App-designed controls | [Custom interfaces](docs/CUSTOM_INTERFACES.md) / [interactive example](Examples/interactive.py) |
| Production lifecycle | [Developer guide](docs/DEVELOPERS.md) |
| Install Notchwork with your app | [Distribution guide](docs/DISTRIBUTION.md) |
| Diagnose a hidden card or failed connection | [Troubleshooting](docs/TROUBLESHOOTING.md) / [doctor](scripts/doctor.py) |
| Contribute or report a bug | [Contributing](CONTRIBUTING.md) / [issue templates](.github/ISSUE_TEMPLATE) |

## Status and compatibility

The default branch contains the API 2 development line (`0.2.0`, build 6). The HTTP route remains `/v1/activity`; discover capability from `ping.apiVersion`, not the URL. Older release tags do not provide this contract. Pin a tested commit for your app. Local build artifacts are ad-hoc signed, not notarized public releases.

The connection is local and authenticated with a per-launch bearer token. It trusts clients running under the same macOS account; source IDs are labels, not verified app identities. Sandboxed pairing is not implemented. See [security](SECURITY.md).

## License

[PolyForm Noncommercial 1.0.0](LICENSE). Commercial use requires separate permission. Include [LICENSE](LICENSE) and [NOTICE](NOTICE) when distributing the runtime or SDK.
