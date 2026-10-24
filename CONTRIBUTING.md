# Contributing

## Scope

Notchwork owns the generic container, API, settings, and lifecycle. Keep app-specific adapters, commands, credentials, and business logic in client repositories. Every added API must work for more than one named app.

## Local checks

Requires macOS 14+ and the Xcode Swift toolchain. From the repository root:

```sh
python3 scripts/check-release.py
python3 -m unittest discover -s Tests -p 'test_*.py'
zsh test.sh
swift build --package-path Examples/HelloNotch
zsh build.sh
```

For schema checks, create a development virtual environment, install `requirements-dev.txt`, then run `python3 scripts/check-schema.py`. Runtime clients do not need these packages.

For a live example check, build first, then run:

```sh
python3 Tests/developer_smoke.py dist/Notchwork.app/Contents/MacOS/Notchwork
```

It starts a temporary-profile host, verifies the example client against the real API, then stops only that process and removes its temporary files. Run on a logged-in Mac desktop. CI skips the existing native timing tests that need a graphical login.

## Pull requests

Explain the user-visible behavior, add targeted contract tests, update the schema/API/examples/prompts together when a contract changes, and include validation results. Keep tokens and personal paths out of fixtures. Changes to event semantics, permissions, or compatibility need explicit documentation. Do not change licensing as part of an unrelated integration change.
