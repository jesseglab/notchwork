# Ship an app that depends on Notchwork

Notchwork is a shared background app plus an SDK/API. Linking `NotchworkKit` does not install the runtime. Any client can bundle the same runtime; app-specific installation code belongs in the client.

## Development

Build from the same tested Notchwork commit as your SDK. `zsh build.sh` produces `dist/Notchwork.app`, a ZIP, and the CLI. Locally built apps are ad-hoc signed. These artifacts are not a notarized Developer ID release.

For local development, start the runtime yourself. For a complete app, follow the [Portkeeper installer](https://github.com/jesseglab/portkeeper/blob/main/Sources/NotchworkRuntime.swift) and [packaging script](https://github.com/jesseglab/portkeeper/blob/main/build.sh).

## Bundled prerequisite contract

1. Embed the runtime at an app-owned resource path; Portkeeper uses `Contents/Resources/Notchwork/Notchwork.app`.
2. Check `~/Applications/Notchwork.app`, then `/Applications/Notchwork.app`. A compatible bundle has identifier `app.notchwork.host`, `NotchworkAPIVersion >= 2`, an executable, and a valid signature.
3. If missing, copy the bundled runtime into a unique staging directory beside the destination. Verify the staged bundle before moving it into `~/Applications/Notchwork.app`. Clean up the staging directory on failure.
4. Preserve incompatible existing destinations. Report an actionable error instead of silently overwriting them. If another installer wins the race, verify and reuse its result.
5. Launch once in the background using `NSWorkspace`, without activation. If an older host is already running, explain that it needs to be quit. Do not start a second competing notch host.
6. Wait with a bounded retry for connection discovery and an API 2 ping, then register and publish. Bundle metadata alone does not prove the running process supports the API.

The reference installer removes FinderInfo/ResourceFork metadata only from the staged copy before strict signature verification. It preserves quarantine and signed contents. Never bypass verification, erase quarantine as an installation workaround, or fetch and run an unpinned mutable download.

## Public distribution

Choose and document a trusted signing/distribution policy for your product. Verify the expected signing identity in addition to signature integrity where your distribution requires it. The current reference installer checks integrity and bundle/API compatibility; it does not establish a separate vendor-identity trust policy. Sign/notarize your shipping bundles through your own release process and test the installed nested runtime on a clean Mac.

The current license is [PolyForm Noncommercial](../LICENSE). Commercial use requires separate permission. Include [LICENSE](../LICENSE) and [NOTICE](../NOTICE). This change does not alter licensing.

## Sandboxed apps

Automatic App Sandbox pairing is not implemented. The default discovery file lives outside a sandboxed app's container. Network entitlements alone do not grant file access. Do not claim an App Store app can use this flow unchanged; design and implement an explicit permitted pairing mechanism first. See [security](../SECURITY.md).
