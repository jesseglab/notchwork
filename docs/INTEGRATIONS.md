# Connecting a client

Notchwork is a container and API runtime. It contains no built-in player integrations, Portkeeper file watcher, or application business logic.

1. Install or reuse a compatible Notchwork runtime and launch it.
2. Discover its per-launch connection file.
3. Register your app with an ID, display name, and custom-interface declaration.
4. Publish activity, high/mid/low priority, lifetime, and your own optional interface.
5. Read named UI events and perform only your app’s declared actions.
6. On host restart, rediscover, register again, and republish.
7. Remove your activity on shutdown; expiry is the fallback for crashes.

Portkeeper is a client example. Its app bundle contains the prerequisite runtime; it installs it into the user’s Applications folder if no compatible installation exists. There is no manual sharing switch or Portkeeper adapter inside Notchwork.

See [API reference](API.md). App installation, update policy, and business behavior belong to the client or its installer, never to a Notchwork integration module.
