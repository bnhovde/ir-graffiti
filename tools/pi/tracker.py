#!/usr/bin/env python3
"""
IR spot tracker for the Raspberry Pi + OV9281.

Runs headless on the Pi behind the TV. Reads the mono global-shutter camera at a
fixed short exposure, finds the can's IR LED, and broadcasts its position over a
WebSocket. The browser applies the homography and paints - keeping calibration in
the UI, where the corner targets can actually be shown on the TV.

Coordinates sent are normalised IMAGE coordinates (0..1), not screen coordinates.
The Pi stays a dumb blob detector; test-wall.html already has solveHomography.

    # on the Pi
    sudo apt install -y python3-picamera2
    pip3 install websockets numpy
    ./tracker.py --stats

    # anywhere, no camera needed - exercises the same pipeline
    ./tracker.py --source synthetic --stats

Why a fixed short exposure matters more than anything else here: ambient light
accumulates in proportion to exposure time, while a bright LED saturates almost
immediately. At 2 ms a lit room nearly vanishes and the LED still reads 255. This
is the control macOS never let us have, and it does more than any filter.
"""

import argparse
import asyncio
import json
import sys
import threading
import time

import numpy as np

WS_PORT = 8765
HTTP_PORT = 8000


# --------------------------------------------------------------------- detect
class IRTracker:
    """Same pipeline as tools/irtest.py and the browser tracker.

    Rolling background, adaptive threshold, windowed centroid, persistence gate.
    The two non-obvious parts are commented where they appear - both were bugs
    found the hard way.
    """

    def __init__(self, k=10.0, floor=20, min_luma=55, bg_rate=0.02,
                 max_area_frac=0.01, lock_need=3, lock_dist_frac=0.05):
        self.k = k
        self.floor = floor
        self.min_luma = min_luma
        self.bg_rate = bg_rate
        self.max_area_frac = max_area_frac
        self.lock_need = lock_need
        self.lock_dist_frac = lock_dist_frac
        self.bg = None
        self._streak = 0
        self._last = None
        self.stats = {}
        self._buf = None          # preallocated scratch; see detect()

    def reset(self):
        self.bg = None
        self._streak = 0
        self._last = None

    def detect(self, gray):
        """gray: 2-D uint8. Returns a dict or None.

        Written to allocate nothing per frame and to avoid boolean fancy
        indexing, which on a million pixels costs more than everything else in
        here put together. All the heavy numpy calls write into preallocated
        buffers via out=.
        """
        h, w = gray.shape
        n = h * w

        if self._buf is None or self._buf[0].shape != gray.shape:
            self._buf = tuple(np.empty((h, w), np.float32) for _ in range(3))
            self.bg = None
        f, sig, tmp = self._buf

        np.copyto(f, gray)        # uint8 -> float32 in place

        if self.bg is None:
            self.bg = f.copy()
            return None

        np.subtract(f, self.bg, out=sig)
        np.maximum(sig, 0, out=sig)

        mean = float(sig.mean())
        sd = float(sig.std())
        thr = max(self.floor, mean + self.k * sd)

        peak_idx = int(np.argmax(sig))
        peak = float(sig.flat[peak_idx])
        py, px = divmod(peak_idx, w)
        luma = int(gray.flat[peak_idx])

        self.stats = {"max_luma": int(gray.max()), "max_sig": round(peak, 1),
                      "mean": round(mean, 2), "sd": round(sd, 2),
                      "thr": round(thr, 1), "w": w, "h": h}

        # Update the background ONLY where the frame is not currently lit.
        # Otherwise holding the button still burns the LED into the reference
        # and the spot fades after a second or two - you lose the stroke exactly
        # when you stop moving.
        if self.bg_rate:
            np.subtract(f, self.bg, out=tmp)
            tmp *= self.bg_rate
            tmp *= (sig < thr)    # mask as 0/1 multiply, not fancy indexing
            self.bg += tmp

        if peak < thr or luma < self.min_luma:
            self._streak = 0
            self._last = None
            return None

        # Intensity-weighted centroid of the bright pixels around the peak.
        r = max(12, w // 14)
        y0, y1 = max(0, py - r), min(h, py + r)
        x0, x1 = max(0, px - r), min(w, px + r)
        win = sig[y0:y1, x0:x1]
        mask = win >= thr
        area = int(mask.sum())
        if area == 0 or area > self.max_area_frac * n:
            self._streak = 0
            self._last = None
            return None

        wsum = float(win[mask].sum())
        ys, xs = np.nonzero(mask)
        cx = x0 + float((xs * win[ys, xs]).sum()) / wsum
        cy = y0 + float((ys * win[ys, xs]).sum()) / wsum

        # Persistence gate. Noise is spatially random frame to frame; a held LED
        # is not. This replaces an absolute brightness gate, which cost range
        # badly - at distance the dot is dim, not bright.
        near = (self._last is not None and
                np.hypot(cx - self._last[0], cy - self._last[1])
                < self.lock_dist_frac * w)
        self._streak = self._streak + 1 if near else 1
        self._last = (cx, cy)

        return {"x": cx / w, "y": cy / h, "area": area,
                "peak": round(peak), "luma": luma,
                "locked": self._streak >= self.lock_need}


# --------------------------------------------------------------------- source
class PiCamera:
    def __init__(self, width, height, exposure_us=2000, gain=8.0, fps=60):
        from picamera2 import Picamera2
        self.cam = Picamera2()
        # R8 asks libcamera for single-channel 8-bit, which is what a mono
        # sensor gives natively. Some stacks hand back 3 channels anyway, so
        # read() copes with both rather than assuming.
        cfg = self.cam.create_video_configuration(
            main={"size": (width, height), "format": "R8"},
            buffer_count=4,
        )
        self.cam.configure(cfg)
        frame_us = int(1_000_000 / fps)
        self.cam.set_controls({
            "AeEnable": False,          # the entire point of this camera
            "AwbEnable": False,
            "ExposureTime": exposure_us,
            "AnalogueGain": gain,
            "FrameDurationLimits": (frame_us, frame_us),
        })
        self.cam.start()
        time.sleep(0.5)

    def read(self):
        a = self.cam.capture_array("main")
        if a.ndim == 3:
            a = a[:, :, 0]
        return a

    def close(self):
        self.cam.stop()


def v4l2_manual(device, exposure_us, gain, verbose=True, auto=False):
    """Force manual exposure/gain/focus on a UVC camera via v4l2-ctl.

    This is the whole reason a modified webcam becomes usable on a Pi: the
    control that macOS refuses to hand over is available on Linux. Kernel
    versions disagree on the control names, so try both spellings and report
    what actually took - believe the readback, not the request.
    """
    import shutil, subprocess
    if sys.platform == "darwin" or not shutil.which("v4l2-ctl"):
        if verbose:
            print("v4l2   not available - exposure stays on auto "
                  "(expected on macOS; on a Pi: sudo apt install v4l-utils)")
        return False

    dev = f"/dev/video{device}"
    if auto:
        # Used only for the startup health check: a sensor on auto shows read
        # noise, which is what tells a live camera from a dead stream.
        for name in ("auto_exposure=3", "exposure_auto=3", "gain=64"):
            subprocess.run(["v4l2-ctl", "-d", dev, f"--set-ctrl={name}"],
                           capture_output=True, text=True)
        return True
    # exposure_time_absolute is in 100 us units, so 2000 us -> 20
    pairs = [
        ("auto_exposure", "1"), ("exposure_auto", "1"),          # 1 = manual
        ("exposure_time_absolute", str(max(1, exposure_us // 100))),
        ("exposure_absolute", str(max(1, exposure_us // 100))),
        ("exposure_dynamic_framerate", "0"),
        ("gain", str(int(gain))),
        ("focus_automatic_continuous", "0"), ("focus_auto", "0"),
        ("focus_absolute", "0"),
        ("white_balance_automatic", "0"), ("white_balance_temperature_auto", "0"),
    ]
    applied = []
    for name, value in pairs:
        r = subprocess.run(["v4l2-ctl", "-d", dev, f"--set-ctrl={name}={value}"],
                           capture_output=True, text=True)
        if r.returncode == 0:
            applied.append(name)
    if verbose:
        print(f"v4l2   applied: {', '.join(applied) if applied else 'nothing'}")
        r = subprocess.run(["v4l2-ctl", "-d", dev, "--list-ctrls"],
                           capture_output=True, text=True)
        for line in r.stdout.splitlines():
            if any(k in line for k in ("exposure", "gain", "focus")):
                print("      ", line.strip())
    return bool(applied)


class OpenCVCamera:
    """Any UVC webcam.

    On a Pi this is a first-class option, not just a stand-in: v4l2 gives real
    manual exposure, which is the single thing that makes IR tracking robust.
    A modified C910 here is a genuinely usable camera. On macOS the controls
    are refused and detection has to lean on the rolling background and
    adaptive threshold instead.
    """

    def __init__(self, width, height, fps=30, device=0,
                 exposure_us=2000, gain=8.0, **_):
        import cv2
        self.cv2 = cv2
        self.device = device
        for attempt in range(1, 4):
            self._open(width, height, fps)
            # Validate BEFORE going to a short exposure, while the sensor is on
            # auto and every frame should be full of read noise. A frame whose
            # pixels are all one value means the camera enumerated and streamed
            # but never actually started - the C910 does this on a cold plug
            # (the kernel log shows its first probe failing with -5), and the
            # only cure is to close it and open it again. Photo Booth shows the
            # same thing: pick the camera, pick another, pick it back.
            v4l2_manual(device, exposure_us, gain, verbose=False, auto=True)
            f = self._settle(20)
            if f is not None and int(f.max()) > int(f.min()):
                break
            print(f"camera returned a flat frame - reopening ({attempt}/3)")
            self.cap.release()
            time.sleep(0.6)
        else:
            print("camera never produced a live frame. Unplug it and plug it "
                  "back in; if that fails, check it in another app first.")

        cc = int(self.cap.get(cv2.CAP_PROP_FOURCC))
        fourcc = "".join(chr((cc >> 8 * i) & 0xFF) for i in range(4)) if cc else "?"
        print(f"camera actual frame {int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))}"
              f"x{int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))} {fourcc} "
              f"@ {self.cap.get(cv2.CAP_PROP_FPS):.0f} fps")
        # Now drop to the short exposure the tracker actually wants. Re-applied
        # after opening because opening resets controls on some UVC drivers.
        v4l2_manual(device, exposure_us, gain)

    def _open(self, width, height, fps):
        cv2 = self.cv2
        backend = cv2.CAP_AVFOUNDATION if sys.platform == "darwin" else cv2.CAP_V4L2
        self.cap = cv2.VideoCapture(self.device, backend)
        if not self.cap.isOpened():
            sys.exit(f"could not open camera {self.device} "
                     "(on macOS, grant camera access to your terminal)")
        # Ask for MJPEG before asking for a size. V4L2 otherwise hands back
        # uncompressed YUYV, and 720p of that is ~18 MB/s - more than USB 2.0
        # will carry, so the camera silently drops to ~10 fps. Requesting the
        # format first is what makes a 30 fps mode available at all.
        if sys.platform != "darwin":
            self.cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc(*"MJPG"))
        # Height first, then width: AVFoundation negotiates a whole mode, not
        # two independent numbers, and the order changes what you get.
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        self.cap.set(cv2.CAP_PROP_FPS, fps)

    def _settle(self, n):
        """Read n frames and return the last, giving auto exposure time to
        converge. Returns None if the camera stops handing over frames."""
        f = None
        for _ in range(n):
            ok, frame = self.cap.read()
            if not ok:
                return None
            f = frame
        if f is None:
            return None
        return self.cv2.cvtColor(f, self.cv2.COLOR_BGR2GRAY) if f.ndim == 3 else f

    def read(self):
        ok, f = self.cap.read()
        if not ok:
            return np.zeros((2, 2), np.uint8)
        return self.cv2.cvtColor(f, self.cv2.COLOR_BGR2GRAY) if f.ndim == 3 else f

    def close(self):
        self.cap.release()


class SyntheticCamera:
    """A moving dot on a noisy background, so the pipeline can be exercised and
    tested without the hardware."""

    def __init__(self, width, height, fps=60, **_):
        self.w, self.h = width, height
        self.t = 0
        self.rng = np.random.default_rng(0)
        self.led = True
        self.interval = 1.0 / fps if fps else 0
        self._next = time.time()

    def read(self):
        # Real cameras block at their frame rate; this one would spin as fast as
        # the CPU allows and flood the socket, so pace it deliberately.
        if self.interval:
            now = time.time()
            wait = self._next - now
            if wait > 0:
                time.sleep(wait)
            self._next = max(now, self._next) + self.interval
        self.t += 1
        img = (22 + self.rng.random((self.h, self.w)) * 14).astype(np.uint8)
        img[self.h // 3: self.h // 3 + self.h // 3, 40:40 + self.w // 4] = 110
        if self.led:
            cx = int(self.w * (0.5 + 0.3 * np.sin(self.t / 40)))
            cy = int(self.h * (0.5 + 0.2 * np.cos(self.t / 55)))
            yy, xx = np.ogrid[:self.h, :self.w]
            img[(yy - cy) ** 2 + (xx - cx) ** 2 <= 9] = 255
        return img

    def close(self):
        pass


# ----------------------------------------------------------------------- main
def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--source", choices=("picamera", "webcam", "synthetic"),
                   default="picamera",
                   help="webcam runs the whole chain on a laptop before the Pi arrives")
    p.add_argument("--device", type=int, default=0, help="webcam index")
    p.add_argument("--width", type=int, default=1280)
    p.add_argument("--height", type=int, default=800)
    p.add_argument("--fps", type=int, default=60)
    p.add_argument("--exposure", type=int, default=2000,
                   help="microseconds. Short is the whole trick - 2000 is 2 ms")
    p.add_argument("--gain", type=float, default=8.0)
    p.add_argument("--k", type=float, default=10.0, help="threshold, in sigmas")
    p.add_argument("--floor", type=int, default=20)
    p.add_argument("--min-luma", type=int, default=55)
    p.add_argument("--port", type=int, default=WS_PORT)
    p.add_argument("--serve", type=int, default=0,
                   help="also serve the repo over HTTP on this port, e.g. 8000")
    p.add_argument("--send-rate", type=int, default=90,
                   help="max WebSocket messages per second. The browser paints "
                        "at 60; flooding it only adds buffer latency")
    p.add_argument("--stats", action="store_true",
                   help="print a live line for aiming and tuning")
    return p.parse_args()


# --------------------------------------------------------------- live preview
# At 2 ms the camera's frames look black to a human even when detection is
# working perfectly, so aiming the camera by eye is impossible without a
# stretched view - and an exhibition Pi has no screen of its own to put one on.
# Serve it over HTTP instead, and let whoever is aiming watch from a phone.
LATEST = {"gray": None, "blob": None, "stats": {}}
LATEST_LOCK = threading.Lock()


def _encode_preview(boost=True, width=640):
    import cv2
    with LATEST_LOCK:
        gray, blob, stats = LATEST["gray"], LATEST["blob"], dict(LATEST["stats"])
    if gray is None:
        return None
    img = gray
    if width and img.shape[1] > width:
        h = int(img.shape[0] * width / img.shape[1])
        img = cv2.resize(img, (width, h), interpolation=cv2.INTER_AREA)
    lo, hi = int(img.min()), int(img.max())
    if boost and hi > lo:
        # Stretch to full range. Without it a working camera and a camera with
        # its lens covered look identical - both are a black rectangle.
        img = cv2.normalize(img, None, 0, 255, cv2.NORM_MINMAX)
    vis = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    if blob:
        cx = int(blob["x"] * vis.shape[1])
        cy = int(blob["y"] * vis.shape[0])
        colour = (0, 255, 0) if blob["locked"] else (0, 165, 255)
        cv2.circle(vis, (cx, cy), 18, colour, 2)
        cv2.line(vis, (cx - 26, cy), (cx + 26, cy), colour, 1)
        cv2.line(vis, (cx, cy - 26), (cx, cy + 26), colour, 1)
    label = (f"raw {lo}-{hi}  luma {stats.get('max_luma', 0)}  "
             f"sig {stats.get('max_sig', 0):.1f}  thr {stats.get('thr', 0):.1f}  "
             + ("LOCKED" if blob and blob.get("locked")
                else "detecting" if blob else "no detection"))
    for colour, thick in (((0, 0, 0), 3), ((255, 255, 255), 1)):
        cv2.putText(vis, label, (8, vis.shape[0] - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.42, colour, thick, cv2.LINE_AA)
    ok, buf = cv2.imencode(".jpg", vis, [cv2.IMWRITE_JPEG_QUALITY, 70])
    return buf.tobytes() if ok else None


PREVIEW_PAGE = b"""<!doctype html><title>IR camera preview</title>
<style>body{margin:0;background:#111;color:#ddd;font:13px system-ui;text-align:center}
img{max-width:100%;image-rendering:pixelated}p{padding:8px}</style>
<h3>IR camera preview</h3><img src="/preview.mjpg?boost=1">
<p>Contrast is stretched to full range - a correctly exposed IR frame is nearly
black. If this shows only noise with no edges, the lens is blocked or facing
something dark. Add <code>?boost=0</code> to see the true levels.</p>"""


def serve_http(port, root):
    import functools, http.server

    class Handler(http.server.SimpleHTTPRequestHandler):
        def _boost(self):
            return "boost=0" not in (self.path.split("?", 1) + [""])[1]

        def do_GET(self):
            path = self.path.split("?", 1)[0]
            if path == "/preview":
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.send_header("Content-Length", str(len(PREVIEW_PAGE)))
                self.end_headers()
                self.wfile.write(PREVIEW_PAGE)
            elif path == "/snapshot.jpg":
                jpg = _encode_preview(self._boost())
                if not jpg:
                    self.send_error(503, "no frame yet")
                    return
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Content-Length", str(len(jpg)))
                self.end_headers()
                self.wfile.write(jpg)
            elif path == "/preview.mjpg":
                self.send_response(200)
                self.send_header("Content-Type", "multipart/x-mixed-replace; "
                                                 "boundary=frame")
                self.end_headers()
                boost = self._boost()
                try:
                    while True:
                        jpg = _encode_preview(boost)
                        if jpg:
                            self.wfile.write(b"--frame\r\nContent-Type: image/jpeg"
                                             b"\r\nContent-Length: "
                                             + str(len(jpg)).encode()
                                             + b"\r\n\r\n" + jpg + b"\r\n")
                        time.sleep(0.1)      # 10 fps is plenty for aiming
                except (BrokenPipeError, ConnectionResetError):
                    pass
            else:
                super().do_GET()

        def log_message(self, *a):
            pass                              # the stats line owns the terminal

    handler = functools.partial(Handler, directory=root)
    srv = http.server.ThreadingHTTPServer(("", port), handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    print(f"http   serving {root} on :{port}")
    print(f"http   camera preview on :{port}/preview")


async def run(args):
    try:
        import websockets
    except ImportError:
        sys.exit("websockets is missing:\n\n    pip3 install websockets\n")

    Source = {"picamera": PiCamera, "webcam": OpenCVCamera,
              "synthetic": SyntheticCamera}[args.source]
    kw = {"fps": args.fps}
    if args.source == "picamera":
        kw.update(exposure_us=args.exposure, gain=args.gain)
    if args.source == "webcam":
        kw.update(device=args.device, exposure_us=args.exposure, gain=args.gain)
    cam = Source(args.width, args.height, **kw)
    tracker = IRTracker(k=args.k, floor=args.floor, min_luma=args.min_luma)
    clients = set()

    async def handler(ws):
        clients.add(ws)
        print(f"ws     client connected ({len(clients)} total)")
        try:
            await ws.wait_closed()
        finally:
            clients.discard(ws)
            print(f"ws     client gone ({len(clients)} total)")

    async def pump():
        loop = asyncio.get_running_loop()
        frames, t0, last_print = 0, time.time(), 0.0
        last_send, was_fix = 0.0, False
        send_interval = 1.0 / args.send_rate if args.send_rate else 0.0
        while True:
            gray = await loop.run_in_executor(None, cam.read)
            blob = tracker.detect(gray)
            frames += 1
            if args.serve:
                with LATEST_LOCK:
                    LATEST["gray"], LATEST["blob"] = gray, blob
                    LATEST["stats"] = tracker.stats

            now = time.time()
            fix = bool(blob and blob["locked"])
            # Send on a fixed cadence, but never swallow a change of state:
            # dropping the transition to "lost" would leave the pen down.
            if clients and (now - last_send >= send_interval or fix != was_fix):
                msg = json.dumps({"lost": True} if not fix
                                 else {"x": round(blob["x"], 5), "y": round(blob["y"], 5),
                                       "area": blob["area"], "peak": blob["peak"]})
                await asyncio.gather(*(c.send(msg) for c in list(clients)),
                                     return_exceptions=True)
                last_send, was_fix = now, fix

            if args.stats and now - last_print > 0.25:
                s = tracker.stats
                fps = frames / max(1e-6, now - t0)
                where = (f"{blob['x']:.3f},{blob['y']:.3f} area {blob['area']:4d} "
                         f"peak {blob['peak']:3.0f} {'LOCKED' if blob['locked'] else '...'}"
                         if blob else "no detection")
                print(f"\r{fps:5.1f} fps  luma {s.get('max_luma',0):3d}  "
                      f"sig {s.get('max_sig',0):5.1f}  thr {s.get('thr',0):5.1f}  "
                      f"{where}        ", end="", flush=True)
                last_print = now
            if now - t0 > 5:
                frames, t0 = 0, now
            await asyncio.sleep(0)

    if args.serve:
        import os
        serve_http(args.serve, os.path.join(os.path.dirname(__file__), "..", ".."))

    print(f"camera {args.source} {args.width}x{args.height} @ {args.fps} fps, "
          f"{args.exposure} us, gain {args.gain}")
    print(f"ws     listening on :{args.port}")
    async with websockets.serve(handler, "", args.port):
        try:
            await pump()
        finally:
            cam.close()


if __name__ == "__main__":
    try:
        asyncio.run(run(parse_args()))
    except KeyboardInterrupt:
        print()
