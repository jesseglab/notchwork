#!/usr/bin/env python3
"""Send an activity to the running host using only the Python standard library."""
import json
from pathlib import Path
import sys
import urllib.request
connection_file = Path.home() / "Library/Application Support/Notchwork/connection.json"
connection = json.loads(connection_file.read_text())
activity = json.loads(Path(sys.argv[1]).read_text())
request = urllib.request.Request(
    connection["endpoint"] + "/v1/activity",
    data=json.dumps({"operation": "publish", "activity": activity}).encode(),
    headers={"Authorization": "Bearer " + connection["token"], "Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=5) as response:
    print(response.read().decode())
