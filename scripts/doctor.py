#!/usr/bin/env python3
"""Check the current local runtime without printing its bearer token."""
import argparse
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'Examples'))
from notchwork_client import Client, DEFAULT_CONNECTION, NotchworkError

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--connection', type=Path, default=DEFAULT_CONNECTION)
args = parser.parse_args()
try:
    result = Client(args.connection).ping()
    print('Connected to Notchwork API %s.' % result['apiVersion'])
    print('If your card is hidden, check Connected apps, its TTL, and the selected layout mode.')
except (OSError, NotchworkError) as error:
    print('Notchwork is not ready: %s' % error, file=sys.stderr)
    sys.exit(1)
