# Changelog

## 0.2.1 — 2026-10-25 (development preview)

- Hovering or clicking either compact side opens only that app, at its requested interface dimensions.
- One mode opens the selected app from either side; empty/disabled sides do not open their neighbour.
- Pointer exit collapses after 180 ms, including forms and focused editors; only the explicit user pin holds the panel open.
- Legacy client `keepOpen` remains accepted but cannot pin the host. Capabilities advertise `side-hover` and `user-controlled-pinning`.
- Preserve the selected interface through the closing morph instead of rebuilding the combined two-app view.

## 0.2.0 — 2026-10-24 (development preview)

- Shared runtime now owns only the generic notch container, settings, and API; built-in client adapters were removed.
- One, Two, and Multiple modes with meaningful-update priority ordering.
- Source registration, API capability discovery, and explicit presentation.
- Runnable Swift/Python examples, strict loopback reference client, doctor, request schema, lifecycle/distribution guides, and copyable LLM prompts.
- Isolated developer profiles via NOTCHWORK_DATA_DIRECTORY.
- Compact physical-notch sizing with padded icons and an unobtrusive handle on other displays.
- App-owned custom interfaces with live state, forms, declared actions, and persistent editing without hover dismissal.
- Apple silicon DMG and ZIP downloads, command-line client, and SHA-256 checksums.

## 0.1.0 — 2026-10-15

The first source-available developer release of Notchwork.

- Standalone native host with three configurable slots on each side of the notch.
- Independent left and right drawers with source assignments.
- Opt-in priority interruptions, stable ordering, and expiry-based restoration.
- Status, progress, detail lines, and explicit web action buttons.
- Local authenticated HTTP API, Swift client, command-line client, and Python example.
- Reusable SwiftUI/AppKit surface engine with liquid transitions and Reduced Motion support.
- Client endpoint validation and redirect refusal; browser-origin rejection in the host.
- Reproducible build packaging, checksums, test workflow, documentation, and visual guide.
- PolyForm Noncommercial 1.0.0 license for the app and SDK.

This version does not include verified app identity, monitor selection, launch at login, or notarized binaries. Optional layout examples are labeled separately from live integrations.

### Live integrations

- Independent Apple Music and Spotify adapters with opt-in Automation access.
- Portkeeper snapshot bridge with event-driven updates, bounded payloads, and crash expiry.
- `notchworkctl run` for actual command status, exit codes, and signal forwarding.
- Live integration controls separate from sample activities.

### App-owned interfaces

- Optional custom PNG icons and opt-in HTML/CSS/JavaScript panels in the shared host.
- Bounded named UI-event callbacks for integrations, with source scope, cursors, and expiry.
- Offline WebKit policy and page cleanup when surfaces detach.
- Portkeeper now links NotchworkKit for native surface motion and typed shared-host integration.
