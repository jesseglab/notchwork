# Releasing Notchwork

The current release is **0.2.0 (build 9)**, an API 2 development preview. Release publishing is a maintainer action; CI builds and checks artifacts but does not publish releases or tags.

## Release checks

- Confirm the README, app version, release notes, and current container/API behavior agree.
- Keep PolyForm Noncommercial 1.0.0 and NOTICE with source and binaries.
- Run `python3 scripts/check-release.py`, the Python/schema checks in [CONTRIBUTING](../CONTRIBUTING.md), `zsh test.sh`, and `zsh build.sh`.
- Inspect the app in a graphical Mac session, including One, Two, Multiple, custom interfaces, and Reduced Motion. Run `python3 Tests/developer_smoke.py dist/Notchwork.app/Contents/MacOS/Notchwork` against its isolated temporary profile.
- Run `zsh scripts/build-dmg.sh`. It derives the version from Info.plist, rejects a mismatched app archive, and verifies that the mounted DMG contains the unchanged signed app and installer layout.
- Verify ZIP signatures after extraction outside cloud-synced storage, archive privacy, and architecture. Label downloads by the architecture actually built; do not call an arm64 build universal or Intel-tested.
- Push reviewed source and wait for CI to pass. Create a versioned GitHub prerelease with the reviewed commit as its target. Upload and verify all assets before publishing.

Previously tested app artifacts can be packaged unchanged when subsequent commits only change documentation, tests, or packaging. Verify the executable sources and app metadata have not changed, and record the release commit and bundled runtime version in the notes.

## Companion dependency order

Publish Notchwork **v0.2.0** before Portkeeper **v1.3.3**. Portkeeper needs Notchwork 0.2.0 build 9 or newer and the `interface-forms` capability. Its distribution includes the matching runtime and installs it if needed. Source builds use sibling checkouts or an explicit `NOTCHWORK_PACKAGE_PATH`; CI pins a tested Notchwork commit.

## Release contents

- Source at the reviewed version tag.
- `Notchwork-0.2.0-arm64-development.dmg`, with the branded drag-to-Applications layout.
- `Notchwork-0.2.0-arm64-development.zip`, containing the same app.
- `notchworkctl-0.2.0-arm64-development.zip`, containing the CLI, LICENSE, and NOTICE.
- `SHA256SUMS`, covering the final downloadable artifacts and license files.
- LICENSE and NOTICE alongside the downloads.

Notes must describe macOS 14+, architecture, development status, installation, compatibility, license, and known limitations. Use version-specific download links in the README because prereleases are not necessarily selected by GitHub’s `/releases/latest` redirect.

## Signing and notarization

The current binaries are ad-hoc signed, not Developer ID signed or notarized. State this on the download page: macOS may block downloaded builds on first launch. A DMG does not change this status. Do not recommend disabling Gatekeeper globally.

Developer ID distribution requires an existing authorized signing identity, notarization credentials, a successful submission, stapling, and verification of the final distributed artifact. These are not assumed by the development release workflow. If notarized builds are introduced, recreate the ZIP and DMG from the final signed app and regenerate every checksum.
