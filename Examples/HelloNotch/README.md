# HelloNotch — runnable Swift client

Build/start the current Notchwork runtime first. From the Notchwork repository root:

```sh
swift run --package-path Examples/HelloNotch HelloNotch --present
```

It discovers the host, checks API 2, registers, publishes, optionally presents, waits 10 seconds, and removes its card. Without `--present` it never opens the container. The TTL handles abrupt termination.

The sample uses the local repository (`../..` relative to this package). `NOTCHWORK_PACKAGE_PATH` may select another local checkout. `NOTCHWORK_CONNECTION_FILE` may select an isolated host's connection file.

This is intentionally a short-lived client. For persistent apps, add the heartbeat/reconnect/event lifecycle in [the guide](../../docs/DEVELOPERS.md). No secrets or additional Swift dependencies are required.
