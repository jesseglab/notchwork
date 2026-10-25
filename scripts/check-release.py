#!/usr/bin/env python3
"""Check local documentation targets and release metadata without network access."""
from pathlib import Path
import plistlib
import re
import sys
import subprocess
root = Path(__file__).resolve().parent.parent
errors = []
for file in root.rglob('*.md'):
    relative = file.relative_to(root)
    if any(part in {'.git', '.build', 'dist', '.swiftpm'} for part in relative.parts):
        continue
    content = file.read_text()
    for target in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)(?:\s+"[^"]*")?\)', content):
        if target.startswith(('https://', 'http://', 'mailto:', '#')):
            continue
        path = target.split('#')[0]
        if path and not (file.parent / path).exists():
            errors.append(f'{relative}: missing link target {target}')
    if '/Users/' in content:
        errors.append(f'{relative}: contains a personal absolute path')
with (root / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
if info['CFBundleShortVersionString'] != '0.2.1':
    errors.append('Info.plist: unexpected release version')
if 'PolyForm Noncommercial License 1.0.0' not in (root / 'LICENSE').read_text():
    errors.append('LICENSE: expected noncommercial license missing')
if info.get('NotchworkAPIVersion') != 2:
    errors.append('Info.plist: expected API version 2')
subprocess.run([sys.executable, str(root / 'scripts/generate-llm-context.py'), '--check'], check=True)
for asset in ['hero.png', 'layout.svg', 'priority.svg']:
    if not (root / 'docs/assets' / asset).is_file():
        errors.append(f'Missing visual: {asset}')
if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print('Documentation links, license, version, and visual assets passed.')
