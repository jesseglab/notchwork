#!/usr/bin/env python3
"""Run against an isolated host: python3 Tests/api_smoke.py CONNECTION_FILE CLI_PATH."""
import copy
import json
from pathlib import Path
import stat
import subprocess
import sys
import urllib.request
import urllib.error

file = Path(sys.argv[1])
connection = json.loads(file.read_text())
assert stat.S_IMODE(file.stat().st_mode) == 0o600
assert connection['endpoint'].startswith('http://127.0.0.1:')
checks = 2

def request(payload, token=None, raw=False, origin=None):
    data = payload if raw else json.dumps(payload).encode()
    req = urllib.request.Request(connection['endpoint'] + '/v1/activity', data=data,
        headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + (connection['token'] if token is None else token)}, method='POST')
    if origin: req.add_header("Origin", origin)
    try:
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())

def expect(condition, message):
    global checks
    assert condition, message
    checks += 1
    print('PASS:', message)

expect(request({'operation': 'ping'})[0] == 200, 'Authenticated health request')
expect(request({'operation': 'ping'}, token='invalid')[0] == 401, 'Incorrect token rejected')
expect(request({'operation': 'ping'}, origin='https://example.com')[0] == 403, 'Browser-origin request rejected')
expect(request(b'not json', raw=True)[0] == 400, 'Malformed JSON rejected')
expect(request({'operation': 'run-shell'})[0] == 400, 'Unknown operations rejected')
card = {'id': 'test', 'sourceID': 'test.api', 'sourceName': 'API test', 'title': 'Published from another process',
        'subtitle': 'Integration smoke check', 'symbol': 'checkmark.circle', 'priority': 'normal', 'preferredSide': 'right',
        'details': [], 'actions': [], 'ttl': 2}
expect(request({'operation': 'publish', 'activity': card})[0] == 200, 'Activity publication accepted')
card['title'] = 'Updated from another process'
expect(request({'operation': 'publish', 'activity': card})[0] == 200, 'Activity update accepted')
invalid = copy.deepcopy(card); invalid['actions'] = [{'title': 'Run', 'url': 'file:///tmp/command'}]
expect(request({'operation': 'publish', 'activity': invalid})[0] == 400, 'Executable action scheme rejected')
expect(request({'operation': 'remove', 'sourceID': 'test.api', 'id': 'test'})[0] == 200, 'Activity removal accepted')
output = subprocess.check_output([sys.argv[2], '--connection', str(file), 'ping'], text=True)
expect('ready' in output, 'Swift SDK command-line client round trip')
print(f'{checks} local API checks passed.')
