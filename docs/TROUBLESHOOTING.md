# Troubleshooting

Start with `python3 scripts/doctor.py` from the repository. It reports readiness without printing credentials.

| Symptom | Check / fix |
| --- | --- |
| Connection file missing | Start `dist/Notchwork.app`, then rerun the doctor. Check that an older runtime is not holding the host lock. |
| API version missing or below 2 | Quit the old host and build/start the current default branch. Old 0.1.x tags do not support registration/presentation. |
| Connection refused or HTTP 401 | Rediscover the connection file and create a new client. The host rotates port/token on restart. |
| Publish succeeds, but no card appears | Check Show under Connected apps, TTL, and One/Two assignments. Try Multiple or explicitly present the example. |
| Plain card instead of custom controls | Register with `customInterface: true`; an existing Custom UI opt-out remains disabled until the user changes it in settings. |
| High priority does not replace a pinned app | One/Two preserve assignments. Priority arbitration happens in Multiple. |
| HTML controls do nothing | Keep your client event loop running; validate source/activity/action/value, use the current cursor and token, and ensure the action is declared. |
| Card vanishes after a minute | Refresh before TTL expires. Use the same full payload for a heartbeat. |
| Inputs reset on updates | Avoid changing `interface.html` for summary-only updates. Keep durable form state in your app. |
| HTTP 400 | Check required fields, ID format, TTL, action URLs, and interface limits against the API/schema. Publish a full payload. |
| HTTP 403 | Browser-origin requests are intentionally rejected. Use your native process, not a browser fetch to the host. |
| HTTP 413 | Request body exceeds 16 MiB. Reduce embedded HTML/icon content. |
| “Notchwork could not be verified” | Rebuild/reinstall the complete trusted app bundle; do not disable signature verification. |
| Incompatible installation | Preserve/move aside the old runtime yourself, quit it, and retry from the client. |
| Sandbox cannot discover host | Automatic sandbox pairing is not implemented; see the distribution guide. |

## Isolated development

Use a dedicated profile so experiments do not touch user assignments:

```sh
NOTCHWORK_DATA_DIRECTORY="$(mktemp -d)" dist/Notchwork.app/Contents/MacOS/Notchwork
```

In another terminal, pass that directory's `connection.json` with `--connection PATH` to the Python examples/doctor, or set `NOTCHWORK_CONNECTION_FILE` for HelloNotch. Do not publish the file or its token. Stop your test host when finished. Use only one visible host at a time when testing window placement.

## Filing a useful issue

Include macOS/architecture, Notchwork commit and API version, client language, expected/actual result, and a minimal redacted activity. State whether the problem occurs in One, Two, or Multiple. Never attach `connection.json`, bearer tokens, service secrets, or private logs. Use [the integration issue template](../.github/ISSUE_TEMPLATE/integration.yml).
