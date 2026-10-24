#!/usr/bin/env python3
"""Exercise developer examples against a real host using an isolated profile."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'Examples'))
from notchwork_client import Client, NotchworkError, activity
from interactive import SOURCE


def wait_for_host(process, file, old_token=None):
    for _ in range(100):
        if process.poll() is not None:
            raise RuntimeError('Test host exited before discovery')
        try:
            client = Client(file)
            if client.session_id != old_token:
                client.ping()
                return client
        except (OSError, NotchworkError):
            pass
        time.sleep(.1)
    raise RuntimeError('Test host did not become ready')


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=6)
        except subprocess.TimeoutExpired:
            process.kill(); process.wait()


with tempfile.TemporaryDirectory(prefix='notchwork-developer-') as folder:
    file = Path(folder) / 'connection.json'
    env = dict(os.environ, NOTCHWORK_DATA_DIRECTORY=folder)
    executable = str(Path(sys.argv[1]).resolve())
    host = subprocess.Popen([executable], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    interactive = None
    try:
        client = wait_for_host(host, file)
        subprocess.run([sys.executable, str(root/'scripts/doctor.py'), '--connection', str(file)], check=True)
        subprocess.run([sys.executable, str(root/'Examples/publish.py'), str(root/'Examples/build.json'), '--connection', str(file), '--present'], check=True)
        for level in ['low', 'mid', 'high']:
            client.publish(activity('test.developer', 'Developer test', 'Priority', priority=level))
        client.remove('test.developer', 'status')
        interactive = subprocess.Popen([sys.executable, str(root/'Examples/interactive.py'), '--connection', str(file), '--duration', '14'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        # Wait for registration as evidence the example connected before restart.
        preferences = Path(folder) / 'preferences.json'
        for _ in range(80):
            if preferences.exists() and any(s['id']==SOURCE for s in json.loads(preferences.read_text())['sources']):
                break
            time.sleep(.1)
        else:
            raise RuntimeError('Interactive example did not register')
        previous_token = client.session_id
        stop(host)
        host = subprocess.Popen([executable], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        client = wait_for_host(host, file, previous_token)
        output, _ = interactive.communicate(timeout=25)
        assert interactive.returncode == 0, output
        assert output.count('Connected.') >= 2, output
        try:
            client.present(SOURCE, 'status')
        except NotchworkError:
            pass
        else:
            raise AssertionError('Interactive example failed to remove its activity')
        if len(sys.argv) > 2:
            subprocess.run([str(Path(sys.argv[2]).resolve()), '--present'], env=dict(os.environ, NOTCHWORK_CONNECTION_FILE=str(file)), check=True)
            try:
                client.present('com.example.hello-notch', 'hello')
            except NotchworkError:
                pass
            else:
                raise AssertionError('Swift example failed to remove its activity')
        print('PASS: doctor, full publication, priorities, custom registration, restart/reconnect, cleanup, and supplied Swift sample')
    finally:
        stop(interactive)
        stop(host)
