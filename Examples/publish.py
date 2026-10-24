#!/usr/bin/env python3
"""Publish a JSON activity using only Python's standard library."""
import argparse
import json
import sys
from pathlib import Path
from notchwork_client import Client, DEFAULT_CONNECTION, NotchworkError


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('activity', type=Path)
    parser.add_argument('--connection', type=Path, default=DEFAULT_CONNECTION)
    parser.add_argument('--present', action='store_true', help='Explicitly open this activity after publishing')
    args = parser.parse_args()
    try:
        card = json.loads(args.activity.read_text())
        client = Client(args.connection)
        client.ping()
        client.register(card['sourceID'], card['sourceName'], bool(card.get('interface')))
        client.publish(card)
        if args.present:
            client.present(card['sourceID'], card['id'])
        print('Published. The activity expires after %s seconds.' % card['ttl'])
    except (OSError, ValueError, KeyError, NotchworkError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
