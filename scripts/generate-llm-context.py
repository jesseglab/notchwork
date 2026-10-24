#!/usr/bin/env python3
"""Build one attachable LLM context document from the maintained source docs."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parent.parent
files = ['docs/QUICKSTART.md', 'docs/API.md', 'docs/DEVELOPERS.md', 'docs/CUSTOM_INTERFACES.md', 'docs/DISTRIBUTION.md', 'SECURITY.md']
content = '# Notchwork API 2 — integration context\n\nGenerated from maintained repository docs. Relative links refer to https://github.com/jesseglab/notchwork/blob/main/ . Read source code for the exact revision you integrate.\n\n'
for name in files:
    content += '\n---\nSOURCE: ' + name + '\n\n' + (root / name).read_text()
output = root / 'llms-full.txt'
if '--check' in sys.argv:
    if not output.exists() or output.read_text() != content:
        sys.exit('llms-full.txt is stale; run python3 scripts/generate-llm-context.py')
else:
    output.write_text(content)
