"""Dependency-free reference client for Notchwork API 2 (Python 3.9+)."""
import http.client
import json
from pathlib import Path
from urllib.parse import urlsplit

DEFAULT_CONNECTION = Path.home() / 'Library/Application Support/Notchwork/connection.json'


class NotchworkError(RuntimeError):
    pass


class Client:
    def __init__(self, connection_file=DEFAULT_CONNECTION):
        try:
            raw = Path(connection_file).read_bytes()
            if len(raw) > 4096:
                raise ValueError('Connection file is too large')
            data = json.loads(raw)
            endpoint = urlsplit(data['endpoint'])
            if (endpoint.scheme != 'http' or endpoint.hostname != '127.0.0.1'
                    or not endpoint.port or endpoint.username is not None
                    or endpoint.password is not None or endpoint.query or endpoint.fragment
                    or endpoint.path not in ('', '/')):
                raise ValueError('Expected an IPv4 loopback endpoint')
            token = data['token']
            if not isinstance(token, str) or not token or any(c in token for c in '\r\n'):
                raise ValueError('Invalid connection token')
            self.port = endpoint.port
            self.session_id = token  # Compare on reconnect; never log this value.
        except FileNotFoundError as error:
            raise NotchworkError('Start Notchwork first, or pass its connection file with --connection.') from error
        except (ValueError, KeyError, TypeError) as error:
            raise NotchworkError('Invalid Notchwork connection file; rediscover the running host.') from error

    def send(self, operation, **fields):
        body = json.dumps(dict(operation=operation, **fields), allow_nan=False).encode()
        if len(body) > 65536:
            raise NotchworkError('Request exceeds the 64 KiB body limit.')
        # A direct connection ignores proxy environment variables and never follows redirects.
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=5)
        try:
            connection.request('POST', '/v1/activity', body=body, headers={
                'Authorization': 'Bearer ' + self.session_id,
                'Content-Type': 'application/json',
            })
            response = connection.getresponse()
            raw = response.read(131073)
            if len(raw) > 131072:
                raise NotchworkError('Host response exceeds the client limit.')
            try:
                result = json.loads(raw)
            except ValueError as error:
                raise NotchworkError('Host returned an invalid JSON response.') from error
            if not isinstance(result, dict):
                raise NotchworkError('Host returned an unexpected response.')
            if response.status != 200 or result.get('ok') is not True:
                raise NotchworkError('Host rejected the request (HTTP %d): %s' %
                                     (response.status, result.get('message', 'No details')))
            return result
        except http.client.HTTPException as error:
            raise NotchworkError("The local host connection was interrupted; rediscover and retry.") from error
        finally:
            connection.close()

    def ping(self):
        result = self.send('ping')
        if result.get('apiVersion', 0) < 2:
            raise NotchworkError('This example requires Notchwork API 2. Build the current runtime.')
        return result

    def register(self, source_id, name, custom_interface=False):
        return self.send('register', registration=dict(id=source_id, name=name, customInterface=custom_interface))

    def publish(self, activity):
        return self.send('publish', activity=activity)

    def remove(self, source_id, activity_id):
        return self.send('remove', sourceID=source_id, id=activity_id)

    def present(self, source_id, activity_id):
        return self.send('present', sourceID=source_id, id=activity_id)

    def events(self, source_id, after=0, wait=True):
        return self.send('events', sourceID=source_id, after=after, wait=wait).get('events', [])


def activity(source_id, name, title, activity_id='status', priority='low', **fields):
    """Supply every required JSON field; keyword fields override defaults."""
    result = dict(id=activity_id, sourceID=source_id, sourceName=name, title=title,
                  subtitle='', symbol='app', priority=priority, preferredSide='left',
                  details=[], actions=[], ttl=60)
    result.update(fields)
    return result
