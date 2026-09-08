#!/usr/bin/env python3
"""Measure how reliably the tracker holds a fix, straight off the WebSocket.

The --stats line is a live display, not a record: it is overwritten in place,
and on a C910 the MJPEG decoder interleaves warnings into the same stream, so
tailing a log tells you about your sampling rather than about the can. This
subscribes to what the tracker actually broadcasts and counts it.

Made for the cone test - hold the can at a fixed distance, rotate it, and watch
where the lock rate falls off:

    ./measure.py                 # live, rolling 2 s window, Ctrl-C for a summary
    ./measure.py --seconds 10    # one 10 s sample, then a summary
"""
import argparse, asyncio, json, sys, time
from collections import deque

import websockets


async def run(url, seconds, window):
    hist = deque()                      # (t, locked, peak, area)
    t0 = time.time()
    print(f"connecting to {url} ...", file=sys.stderr)
    async with websockets.connect(url, open_timeout=10) as ws:
        print("connected. Hold the button and rotate the can.\n", file=sys.stderr)
        last_print = 0.0
        while True:
            now = time.time()
            if seconds and now - t0 >= seconds:
                break
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=1.0)
            except asyncio.TimeoutError:
                # Silence is data: the tracker only sends on a cadence, so a gap
                # means no fix, not a dead link.
                hist.append((time.time(), False, 0, 0))
                continue
            m = json.loads(raw)
            fix = not m.get("lost") and isinstance(m.get("x"), (int, float))
            hist.append((time.time(), fix, m.get("peak", 0), m.get("area", 0)))
            while hist and hist[0][0] < time.time() - window:
                hist.popleft()
            if time.time() - last_print >= 0.5 and hist:
                n = len(hist)
                lk = sum(1 for h in hist if h[1])
                pk = [h[2] for h in hist if h[1]]
                ar = [h[3] for h in hist if h[1]]
                bar = "#" * int(20 * lk / n)
                print(f"\rlock {100*lk/n:5.1f}% |{bar:<20}|  "
                      f"peak {max(pk) if pk else 0:3.0f}  "
                      f"area {max(ar) if ar else 0:5d}   ",
                      end="", flush=True)
                last_print = time.time()
    return hist


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", default="ws://localhost:8765")
    p.add_argument("--seconds", type=float, default=0, help="0 = until Ctrl-C")
    p.add_argument("--window", type=float, default=2.0, help="rolling window, s")
    a = p.parse_args()
    try:
        asyncio.run(run(a.url, a.seconds, a.window))
    except KeyboardInterrupt:
        pass
    print()


if __name__ == "__main__":
    main()
