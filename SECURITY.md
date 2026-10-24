# Security

Notchwork 0.2 is intended for trusted local integrations on a single macOS account.

## Boundary

The server listens only on IPv4 loopback and checks a per-launch bearer token. The connection directory and file are owner-only. Requests and connection lifetimes are bounded. Browser-origin requests are rejected. The Swift client validates its loopback endpoint and refuses redirects; it uses an ephemeral session without cookies.

A bearer token grants access to the entire activity host. Source names and IDs are declared by integrations, not verified application identities. They are preferences, not separate security principals. A process with access to the token can impersonate a source or remove its cards. This release does not provide signed app pairing, per-app tokens, or granular revocation.

The host displays activity cards and permitted custom WebKit interfaces. It does not execute shell commands or load native plugin code. Web actions open only on explicit user clicks, using http(s) URLs without embedded credentials. Live activity payloads are memory-only; assignments and source names persist locally.

## Reporting

Do not put tokens or exploit details into public issues. Use GitHub's private vulnerability reporting if enabled for this repository. If that option is unavailable, open a minimal issue asking the maintainer for a private reporting channel without disclosing the vulnerability. A dedicated reporting address is not yet configured.

No external security audit has been performed. Signing and notarization status are documented per release; an ad-hoc development signature is not Developer ID distribution approval.

## Client-owned integrations

Notchwork has no built-in Music, Spotify, or Portkeeper adapters. Apps publish through the local API and execute their own validated actions. `notchworkctl run` executes only a command supplied by the person invoking the CLI; it does not publish arguments, environment, or output. The host API cannot execute commands.

## Custom interfaces

Unregistered sources have custom HTML/JavaScript interfaces disabled by default. An authenticated client may register a new source with custom-interface support enabled. Re-registration cannot override existing user restrictions. This uses the shared-token trust boundary described above. A permitted interface runs in WebKit with a nonpersistent data store, restrictive content security policy, and denied external navigation. The host does not provide file paths, credentials, or the API token to the page. Only declared, bounded action/value messages from the main frame become events; the integration app must validate them before acting. The shared bearer token can read events across sources. Custom UI is intended for trusted local integrations, not hostile-code execution. The host clears detached pages, which stops their scripts. Keep native executable code in the owning app through the SDK rather than loading plugins into the host.
