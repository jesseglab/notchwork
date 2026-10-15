# Contributing

Small, focused improvements are welcome. Start with an issue for a larger adapter, API change, or interaction redesign.

## Local development

Use macOS 14+ with an Xcode Swift toolchain. There are no external package dependencies.

```sh
zsh build.sh
zsh test.sh
```

For the isolated demo profile:

```sh
./dist/Notchwork.app/Contents/MacOS/Notchwork --preview
```

The preview uses `Notchwork-preview` under the user's temporary directory. Normal launches use Application Support. Avoid running another notch host at the same time. Quit the test app when finished.

The test suite covers activity validation, ordering, interruption policy, expiry, preference persistence, and native motion. The native window timing test needs a logged-in macOS desktop. CI skips only that test and runs the state/model tests plus a release build. CI results are authoritative only after a run has actually completed.

API smoke checks target an already running isolated preview:

```sh
python3 Tests/api_smoke.py "$TMPDIR/Notchwork-preview/connection.json" dist/notchworkctl
```

## Review expectations

Explain the behavior change and how it was checked. Preserve Reduced Motion, keyboard access, hidden-view suspension, stable equal-priority ordering, and the loopback trust boundary. Do not add polling for behavior that can be event-driven.

Keep fixtures synthetic. Do not commit tokens, connection files, local preferences, personal logs, signing credentials, or generated build products. For a bug, include macOS version, architecture, expected behavior, and a minimal reproduction.

## License

This project is source-available under PolyForm Noncommercial 1.0.0. Submit only code and assets you have the right to contribute under the project's license. Contributors retain their copyright; a contribution does not assign ownership or grant the maintainer additional commercial relicensing rights. Any separate commercial license involving contributed code requires the necessary rightsholders' permission.
