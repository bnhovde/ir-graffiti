#!/usr/bin/env python3
"""Drive the wall app in a kiosk browser over the Chrome DevTools Protocol.

The exhibition Pi has no mouse or keyboard, so the page has to be operated
from outside it. Launch Chromium with --remote-debugging-port=9222 and this
evaluates JavaScript in the page from an SSH session.

    ./kiosk.py 'app.camMode'                  # read something
    ./kiosk.py --connect ws://localhost:8765  # go live on the Pi tracker
    ./kiosk.py --calibrate                    # start the 4-corner calibration
    ./kiosk.py --status                       # tracker state and last fix
"""
import asyncio, json, sys, urllib.request
import websockets

CDP = "http://localhost:9222"


async def evaluate(expr, timeout=30):
    targets = json.load(urllib.request.urlopen(f"{CDP}/json"))
    page = next((t for t in targets
                 if t["type"] == "page" and "test-wall" in t["url"]), None)
    if not page:
        sys.exit("no test-wall page target - is the kiosk browser running?")
    async with websockets.connect(page["webSocketDebuggerUrl"],
                                  max_size=None, open_timeout=10) as ws:
        await ws.send(json.dumps({
            "id": 1, "method": "Runtime.evaluate",
            "params": {"expression": expr, "awaitPromise": True,
                       "returnByValue": True}}))
        async with asyncio.timeout(timeout):
            while True:
                m = json.loads(await ws.recv())
                if m.get("id") != 1:
                    continue
                r = m.get("result", {})
                if "exceptionDetails" in r:
                    d = r["exceptionDetails"]
                    sys.exit("JS error: " + d.get(
                        "exception", {}).get("description", d.get("text", "?")))
                return r.get("result", {}).get("value")


# A screen wake lock, not a compositor setting: the app itself is what must
# keep the TV awake, and it is the only part that knows it is on show.
WAKELOCK = """
(async () => {
  try {
    window._wakeLock = await navigator.wakeLock.request('screen');
    document.addEventListener('visibilitychange', async () => {
      if (document.visibilityState === 'visible')
        try { window._wakeLock = await navigator.wakeLock.request('screen'); }
        catch (e) {}
    });
    return 'held';
  } catch (e) { return 'failed: ' + e.message; }
})()"""


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    if args[0] == "--connect":
        url = args[1] if len(args) > 1 else "ws://localhost:8765"
        expr = f"""(async () => {{
          const wl = await {WAKELOCK};
          app.setCamMode('pi');
          app.piTracker.connect({url!r});
          await new Promise(r => setTimeout(r, 2500));
          return {{ wakeLock: wl, mode: app.camMode,
                   state: app.piTracker.state, stats: app.piTracker.stats }};
        }})()"""
    elif args[0] == "--calibrate":
        expr = ("(app.beginIRCalibration(), "
                "({calibrating: !!app._irCalibrating, mode: app.camMode, "
                "state: app.piTracker.state}))")
    elif args[0] == "--status":
        expr = """({
          mode: app.camMode, state: app.piTracker.state,
          calibrated: app.piTracker.calibrated,
          live: !!app.handTrackingOn,
          last: app.piTracker.last, stats: app.piTracker.stats })"""
    elif args[0] == "--wakelock":
        expr = WAKELOCK
    else:
        expr = args[0]
    print(json.dumps(asyncio.run(evaluate(expr)), indent=2))


if __name__ == "__main__":
    main()
