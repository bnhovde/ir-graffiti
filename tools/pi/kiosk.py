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
    # Any page the kiosk is serving, not just the wall: the debug pointer page
    # has to be drivable too, and on a machine with no keyboard this is the only
    # way to press a key at all.
    page = next((t for t in targets
                 if t["type"] == "page" and "localhost:8000" in t["url"]), None) \
        or next((t for t in targets if t["type"] == "page"), None)
    if not page:
        sys.exit("no page target - is the kiosk browser running?")
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
    # --timeout has to outlast the expression itself: a measurement that runs
    # for 30 s inside the page needs more than 30 s of patience outside it.
    timeout = 30
    if "--timeout" in args:
        i = args.index("--timeout")
        timeout = float(args[i + 1])
        del args[i:i + 2]
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
    elif args[0] == "--latency":
        # Run this WHILE painting: it only samples when there is a fix, because
        # the tracker sends a timestamp only with a position.
        secs = float(args[1]) if len(args) > 1 else 20
        expr = f"""(async () => {{
          const t = app.piTracker, lat = []; let frames = 0, seen = null;
          const t0 = performance.now();
          const tick = () => {{ frames++;
            if (performance.now()-t0 < {secs*1000}) requestAnimationFrame(tick); }};
          requestAnimationFrame(tick);
          while (performance.now() - t0 < {secs*1000}) {{
            await new Promise(r => setTimeout(r, 50));
            if (t.latency != null && t.latency !== seen) {{ lat.push(t.latency); seen = t.latency; }}
          }}
          lat.sort((a,b)=>a-b);
          const q = f => lat.length ? lat[Math.min(lat.length-1, Math.floor(lat.length*f))] : null;
          return {{ samples: lat.length, min_ms: q(0), p50_ms: q(0.5),
                   p90_ms: q(0.9), max_ms: q(0.999),
                   rafFps: +(frames/((performance.now()-t0)/1000)).toFixed(1),
                   note: lat.length ? "" : "no fix seen - hold the button at the camera while this runs" }};
        }})()"""
        timeout = max(timeout, secs + 20)
    elif args[0] == "--wakelock":
        expr = WAKELOCK
    else:
        expr = args[0]
    print(json.dumps(asyncio.run(evaluate(expr, timeout)), indent=2))


if __name__ == "__main__":
    main()
