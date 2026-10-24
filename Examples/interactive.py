#!/usr/bin/env python3
"""Custom controls, long-poll events, heartbeat, reconnect, and cleanup."""
import argparse
import time
from pathlib import Path
from notchwork_client import Client, DEFAULT_CONNECTION, NotchworkError, activity

SOURCE = 'com.example.notchwork.interactive'
HTML = '''<style>
body { margin: 0; padding: 20px; background: #101712; color: #ecfff1; font: 15px system-ui }
button { padding: 12px 18px; border: 0; border-radius: 10px; background: #a4f4bd; color: #082213 }
button:focus-visible { outline: 3px solid white; outline-offset: 3px }
</style><h1>Your app, inside Notchwork</h1><p>The Python client handles this action.</p>
<button onclick="notchwork.invoke('acknowledge', 'demo')">Acknowledge</button>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--connection', type=Path, default=DEFAULT_CONNECTION)
    parser.add_argument('--duration', type=float, default=60, help='Run for this many seconds')
    parser.add_argument('--present', action='store_true', help='Open once, at your explicit request')
    args = parser.parse_args()
    card = activity(SOURCE, 'Interactive example', 'Ready for your action',
                    interface=dict(html=HTML, height=220, actions=['acknowledge']))
    client = None
    session = None
    cursor = 0
    count = 0
    present_requested = args.present
    deadline = time.monotonic() + args.duration
    next_heartbeat = 0
    try:
        while time.monotonic() < deadline:
            try:
                if client is None:
                    client = Client(args.connection)
                    client.ping()
                    if client.session_id != session:
                        cursor = 0
                        session = client.session_id
                    client.register(SOURCE, 'Interactive example', custom_interface=True)
                    client.publish(card)
                    next_heartbeat = time.monotonic() + 20
                    print('Connected. Restart Notchwork to try reconnecting.', flush=True)
                if present_requested:
                    # Consume the explicit request once, even if the response is lost.
                    present_requested = False
                    client.present(SOURCE, 'status')
                if time.monotonic() >= next_heartbeat:
                    client.publish(card)  # Same content and ID: no priority promotion.
                    next_heartbeat = time.monotonic() + 20
                for event in client.events(SOURCE, after=cursor):
                    if event['sequence'] <= cursor:
                        continue
                    cursor = event['sequence']  # Also acknowledge deliberately rejected events.
                    if (event['sourceID'] != SOURCE or event['activityID'] != 'status'
                            or event['action'] != 'acknowledge' or event['value'] != 'demo'):
                        continue
                    count += 1
                    card.update(title='Acknowledged %d time(s)' % count,
                                notificationID='ack-%d' % count)
                    client.publish(card)
                    print(card['title'], flush=True)
            except (OSError, NotchworkError) as error:
                print('Connection unavailable: %s Retrying in 2 seconds.' % error, flush=True)
                client = None
                time.sleep(min(2, max(0, deadline - time.monotonic())))
    except KeyboardInterrupt:
        pass
    finally:
        if client:
            try:
                client.remove(SOURCE, 'status')
            except (OSError, NotchworkError):
                pass  # A crash or unavailable host is covered by the activity TTL.


if __name__ == '__main__':
    main()
