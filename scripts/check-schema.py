#!/usr/bin/env python3
"""Validate the schema and example requests (requires requirements-dev.txt)."""
from pathlib import Path
import json
import sys
from jsonschema import Draft202012Validator
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'Examples'))
from interactive import HTML, SOURCE
from notchwork_client import activity
schema = json.loads((root / 'docs/command.schema.json').read_text())
Draft202012Validator.check_schema(schema)
validator = Draft202012Validator(schema)
card = json.loads((root / 'Examples/build.json').read_text())
requests = [dict(operation='ping'), dict(operation='publish', activity=card),
            dict(operation='register', registration=dict(id=SOURCE, name='Example', customInterface=True)),
            dict(operation='publish', activity=activity(SOURCE, 'Example', 'Ready', interface=dict(html=HTML, height=220, actions=['acknowledge']))),
            dict(operation='events', sourceID=SOURCE, after=0, wait=True),
            dict(operation='present', sourceID=SOURCE, id='status'),
            dict(operation='remove', sourceID=SOURCE, id='status')]
for request in requests:
    validator.validate(request)
invalid = [dict(operation='publish', activity={'title':'Missing fields'}),
           dict(operation='present', sourceID=SOURCE), dict(operation='unknown'),
           dict(operation='publish', activity=dict(card, ttl=0)),
           dict(operation='publish', activity=dict(card, priority='critical'))]
for request in invalid:
    assert not validator.is_valid(request), 'Invalid fixture unexpectedly accepted'
print('Schema and %d valid / %d invalid request fixtures passed.' % (len(requests), len(invalid)))
