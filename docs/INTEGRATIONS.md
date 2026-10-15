# Live integrations

Enable integrations in **Notchwork → Configure → Live integrations**. Each connected source can use independent notch slots and drawers. Priority interruption still requires permission in **Connected apps**. The **Load examples** button is only for trying the layout; those cards remain labeled as demos.

## Apple Music and Spotify

Both adapters are built into the host. Enable each player separately, open the player, and allow the macOS Automation request. Notchwork reads the current song, artist, album, and playing/paused state. It does not start playback, launch the player, or read its library.

If access is denied, enable the corresponding player under **System Settings → Privacy & Security → Automation → Notchwork**, then choose **Reconnect** in Notchwork. Development rebuilds may need permission again because they do not have a stable Developer ID signature.

The adapters use each app's scripting dictionary through Apple's Scripting Bridge. Reads run on a utility queue with a two-second timeout per Apple event and no overlapping read for a player. While a player is open, updates arrive about every five seconds. When it quits, the card disappears and polling stops; workspace events reconnect it when it reopens. The adapter never animates a progress clock. A failed read clears the card and shows an error; reconnect after resolving it.

Apple Music uses `app.notchwork.music`; Spotify uses `app.notchwork.spotify`. Assign them to different slots if you want to keep both visible. Other music players require an adapter.

## Portkeeper

Use the companion [Portkeeper](https://github.com/jesseglab/portkeeper) build with **Share service status with Notchwork** in its settings, then enable **Portkeeper** in Notchwork. Older Portkeeper builds do not export the bridge file. The companion update is staged separately; installing it requires a normal Portkeeper restart, which stops its managed services.

The bridge reports real managed service states: starting, running, stopped, failed, unhealthy, and port conflicts. Errors become urgent activities. Names and states are shared; commands, paths, terminal logs, and diagnostic text stay in Portkeeper. Enable **Custom UI** for Portkeeper in Connected apps to show its own branded panel with service start/stop/restart and project restart. The host delivers these actions to the running Portkeeper app. Terminal input and AI troubleshooting stay in its full native interface, opened by the panel’s **Terminals, project handoff & AI** button.

When sharing is enabled, Portkeeper hides its compact notch and drawer handles so Notchwork can occupy those spaces. Opening Portkeeper from its menu bar still temporarily shows its controls. Disable sharing to restore its compact surfaces.

### Bridge contract

Portkeeper atomically writes `~/Library/Application Support/Portkeeper/notchwork.json` with mode `0600`:

```json
{
  "version": 1,
  "sentAt": 1792051200,
  "activity": {
    "id": "services",
    "sourceID": "app.portkeeper",
    "sourceName": "Portkeeper",
    "title": "2 running",
    "subtitle": "0 starting · 2 services",
    "symbol": "terminal",
    "priority": "normal",
    "preferredSide": "right",
    "details": ["Project / API · Running", "Project / Web · Running"],
    "actions": [],
    "ttl": 60
  }
}
```

`sentAt` is the current Unix timestamp; the value above is illustrative. Publish changes at most once per second and refresh every 20 seconds. Delete the file when disconnecting or quitting. The host watches the directory instead of polling, checks size/type/ownership, refuses symlink files, and accepts only the fixed source/activity identity. A missing, invalid, or stale snapshot clears the activity. Freshness expires within 60 seconds even after a crash. This is a same-user local bridge, not cryptographic app identity verification.

[`ActivitySnapshot`](../Sources/NotchworkKit/ActivitySnapshot.swift) defines the payload. The staged Portkeeper companion implements it using NotchworkKit’s typed snapshot, client, and custom-interface definitions. Its native surfaces also link the SDK.

## Builds and scripts

Wrap a command explicitly:

```sh
./dist/notchworkctl run --name "Web build" -- npm run build
./dist/notchworkctl run --name "Tests" -- swift test
```

For shell expressions, invoke a shell yourself:

```sh
./dist/notchworkctl run --name "Checks" -- /bin/sh -c 'npm test && npm run build'
```

The wrapper preserves standard input, output, error output, working directory, and exit status. It sends running/completed/failed state under `app.notchwork.commands` using a unique activity ID for every invocation. Failed commands are urgent; allow priority for this source if you want interruptions. Completion cards expire after 30 seconds. Running cards refresh every 20 seconds and expire after 60 seconds if the wrapper disappears.

The wrapper does not capture or transmit command arguments, environment variables, or terminal output. Your chosen display name is shared, so do not put secrets in it. Ordinary terminal scripts are supported; a new PTY is not created. The host never executes a command received through its API.

The command still runs if the host is unavailable. The wrapper discovers the connection again on each refresh so it can reconnect after a host restart. Sending INT, TERM, or HUP to the wrapper forwards the signal to the managed child/process group. A signal exit is reported as `128 + signal`.

## Native apps and other tools

Use the existing [local API](API.md) or [Swift example](../Examples/NativeIntegration.swift). Installing an arbitrary app does not connect it automatically; supported adapters and explicit integrations provide the data.
