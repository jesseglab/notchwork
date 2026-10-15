# Release candidate validation

15 October 2026 · Notchwork 0.1.0 · Apple silicon

## Completed locally

- Release build completed without compiler warnings.
- 32 Swift tests passed, including native left/right drawer anchoring, motion reversal, expiry, preference persistence, slot policy, payload validation, and client endpoint restrictions.
- 12 API smoke checks passed against the isolated preview profile, including token validation, browser-origin rejection, publish/update/remove, and the Swift CLI.
- Real command-runner checks passed for success, nonzero exit, stdin/stdout/stderr, signal forwarding, missing host, missing executable, and output privacy.
- 119 companion Portkeeper checks passed, including a real managed process publishing status through the bridge, error priority, and snapshot cleanup.
- An additional synthetic HTTP test confirmed the Swift client refuses redirects without forwarding its token.
- Real WebKit rendering passed for custom layout, JavaScript-to-host callbacks, CSP network rejection, and clearing hidden pages.
- Custom-interface permissions, validation, bounded source-scoped queues, acknowledgement cursors, waiting delivery, and shutdown passed. A live local server delivered callbacks without blocking health requests.
- Portkeeper compiled and linked against the actual NotchworkKit dependency; its duplicate surface implementation was removed.
- Documentation links, license presence, release version, and referenced assets passed the local release check.
- Workflow YAML and SVG sources parsed successfully.
- The cover and both diagram exports were visually inspected. The diagrams are explicitly labeled illustrations, not screenshots.
- The app archive's ad-hoc signature was verified after extraction outside cloud-synced storage. License and required notice are bundled with the app and CLI artifacts.

## Not yet performed

- GitHub CI: see the workflow run for the release commit; local results above were completed before publication.
- Developer ID signing, notarization, and Gatekeeper distribution validation: explicitly outside the requested scope.
- Intel hardware testing or universal binary validation.
- External security audit or verified per-app identity/pairing.
- Music playback and track-change verification across both players: adapter controls and closed-player behavior were inspected; Apple Music connected and reported stopped playback. Desktop automation stalled opening Spotify, so its live metadata has not been verified. Music payload mapping, separate source identity, and size limits passed automated tests.
- The final build rejects unrecognized playback states; end-to-end playback still needs a manual check on each player.

The maintainer approved publication of the repositories and development releases on 15 October 2026. Release notes retain the signing, architecture, and integration-testing limitations above.
