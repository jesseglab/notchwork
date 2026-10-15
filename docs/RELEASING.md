# Releasing Notchwork

The initial release is **0.1.0**, a source-available developer preview. The maintainer approved publishing both repositories and development releases on 15 October 2026. Nothing in the CI workflow publishes releases or pushes tags.

## Source preview gate

- Confirm the app name, README, visuals, and release description.
- Keep PolyForm Noncommercial 1.0.0 and NOTICE together with source and binaries.
- Run `python3 scripts/check-release.py`, `zsh test.sh`, and `zsh build.sh`.
- Inspect the app on a logged-in Mac, including both drawers and Reduced Motion.
- Run the local API smoke checks against an isolated preview profile.
- Verify the archive signature after extracting it outside cloud-synced storage.
- After approval, push the reviewed source to `main`, then wait for GitHub CI to pass.
- Review the diff and release contents before creating a `v0.1.0` tag and a GitHub **prerelease**.

The build uses the current machine's architecture. Label uploaded binaries accordingly. Apple silicon has been tested; do not label a build universal or Intel-tested without actually building and checking those architectures.

## Developer ID distribution (outside current scope)

The default build is ad-hoc signed for local development. Do not describe it as notarized or as a frictionless public download. For Developer ID distribution, use an existing signing identity:

```sh
NOTCHWORK_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' zsh build.sh
```

Submit the resulting archive through Apple's notarization process using credentials stored in the maintainer's keychain. If distributing the CLI as a separate download, submit it for notarization too. After success, staple and validate the app, recreate the final ZIP, and regenerate checksums. Verify Gatekeeper assessment on the final distributed app. Never commit identities, private keys, credentials, or connection tokens.

No Developer ID identity, notarization credential, or successful notarization is assumed by this repository. A source release can proceed without promising notarized binaries.

## Companion dependency order

Publish Notchwork and its `v0.1.0` tag before Portkeeper, whose Swift package pins the SDK to version `0.1.0`. Verify a Portkeeper build resolves that remote tag. `NOTCHWORK_PACKAGE_PATH` remains an explicit override for local SDK development.

## Release contents

- Source at the reviewed tag.
- Architecture-labeled app ZIP, when approved for distribution.
- Command-line client with LICENSE and NOTICE.
- SHA256SUMS matching the actual final files.
- Notes describing the supported macOS version, license, and known limitations.

## Suggested repository metadata

Description: **Native macOS notch slots and edge drawers for app activity. Standalone host, local API, and Swift package.**

Topics: `macos`, `swift`, `swiftui`, `notch`, `appkit`, `developer-tools`, `source-available`, `noncommercial`.

Enable private vulnerability reporting before inviting public security reports. Protect the default branch after the initial commit and require CI for subsequent pull requests. These settings are proposed here; they are not changed by a local build.

## Release copy

Notchwork gives app activity a place around your Mac's notch and along either screen edge. This first developer preview includes six configurable slots, independent drawers, opt-in priority activities, and a local integration API. Use the Swift client to publish cards, or embed the native surface engine in your own app.

Requires macOS 14+. Includes Apple Music and Spotify adapters, real command status, and the companion Portkeeper bridge. Sample cards are available separately for layout previews. The app and SDK are source-available under PolyForm Noncommercial 1.0.0. Commercial use requires separate permission. See the release assets for their specific signing and architecture status.
