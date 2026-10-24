# Working on Notchwork

Read README.md and docs/DEVELOPERS.md before changing integration behavior. The authoritative contract is the implementation plus docs/API.md; update docs/command.schema.json, examples, and generated llms-full.txt when it changes.

Keep Notchwork generic: container, API, settings, placement, and lifecycle only. Put app adapters and business logic in client apps. Do not add another notch renderer to a client as a fallback. Preserve user permissions on registration and reconnect. Never present in response to a background update.

Run the relevant checks in CONTRIBUTING.md. Refresh the generated LLM context with python3 scripts/generate-llm-context.py and run python3 scripts/check-release.py. Never publish connection tokens or personal runtime state. Do not change licensing or claim notarization without evidence.
