#!/usr/bin/env python3
"""
IR spot tuner for the graffiti can.

macOS will not let you lock exposure on a UVC camera - uvcc enumerates the C910
but every control transfer hangs, because the system's own UVC driver holds the
interface. So this tool is built to not care: the background is a rolling
average that tracks exposure drift, and the threshold is relative to the frame's
own statistics rather than an absolute level. Auto-exposure can wander and the
spot is still found.

    pip3 install opencv-python
    ./irtest.py

macOS asks for camera permission on first run, granting it to whichever app
launched this - your terminal.

Keys
    p        brightest-pixel mode: no background, no threshold, no area filter.
             The one mode with nothing to misconfigure. Start here.
    b        background: rolling -> frozen -> off
    t        threshold: adaptive (mean + k*sigma) -> absolute
    [ ]      k down / up, or threshold down / up in absolute mode
    a        toggle the area filter
    - =      max blob area down / up      , .   min blob area down / up
    m        view: raw / signal / mask
    s        save a PNG
    q, esc   quit
"""

import argparse
import sys
import time
from collections import deque

import numpy as np

try:
    import cv2
except ImportError:
    sys.exit("opencv is missing:\n\n    pip3 install opencv-python\n")

BG_MODES = ("rolling", "frozen", "off")


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--device", type=int, default=0,
                   help="AVFoundation index; the C910 is 0 on this machine")
    p.add_argument("--width", type=int, default=640)
    p.add_argument("--height", type=int, default=480)
    p.add_argument("--fps", type=int, default=10)
    p.add_argument("--k", type=float, default=8.0,
                   help="adaptive threshold, in sigmas above the frame mean")
    p.add_argument("--threshold", type=int, default=60,
                   help="absolute threshold, used only in absolute mode")
    p.add_argument("--bg-rate", type=float, default=0.02,
                   help="how fast the rolling background follows. 0.02 at 10 fps "
                        "is a ~5 s memory: exposure drift is absorbed, a spray "
                        "stroke is not.")
    p.add_argument("--min-area", type=int, default=None)
    p.add_argument("--max-area", type=int, default=None,
                   help="a spot bounced off a wall is a patch, not a point - "
                        "hundreds to thousands of px. Too small a value here "
                        "throws the spot away and keeps your fragments.")
    return p.parse_args()


def _try_mode(cap, width, height, height_first):
    """AVFoundation negotiates a whole mode, not two independent numbers, so the
    order matters and the result must be read off a real frame, not cap.get()."""
    order = ((cv2.CAP_PROP_FRAME_HEIGHT, height), (cv2.CAP_PROP_FRAME_WIDTH, width))
    if not height_first:
        order = order[::-1]
    for prop, value in order:
        cap.set(prop, value)
    frame = None
    for _ in range(5):
        ok, frame = cap.read()
    if frame is None:
        return None
    h, w = frame.shape[:2]
    return w, h


def open_camera(args):
    backend = cv2.CAP_AVFOUNDATION if sys.platform == "darwin" else cv2.CAP_ANY
    cap = cv2.VideoCapture(args.device, backend)
    if not cap.isOpened():
        sys.exit(f"could not open device {args.device}")

    got = _try_mode(cap, args.width, args.height, height_first=True)
    if got != (args.width, args.height):
        alt = _try_mode(cap, args.width, args.height, height_first=False)
        if alt == (args.width, args.height):
            got = alt
    if got is None:
        sys.exit("camera opened but returned no frames")

    cap.set(cv2.CAP_PROP_FPS, args.fps)
    print(f"frame {got[0]}x{got[1]} @ {cap.get(cv2.CAP_PROP_FPS):g} fps requested")
    if got != (args.width, args.height):
        print(f"  !! asked for {args.width}x{args.height}, camera refused. Try a "
              f"mode it really has:\n     640x480, 800x600, 1280x720.")

    # Try anyway, and say honestly whether it took. On macOS these are normally
    # ignored; the adaptive threshold is what makes that survivable.
    print("\nmanual controls (macOS usually ignores these):")
    for prop, value, name in ((cv2.CAP_PROP_AUTO_EXPOSURE, 0.25, "auto_exposure"),
                              (cv2.CAP_PROP_EXPOSURE, -6, "exposure"),
                              (cv2.CAP_PROP_GAIN, 255, "gain"),
                              (cv2.CAP_PROP_AUTOFOCUS, 0, "autofocus")):
        cap.set(prop, value)
        print(f"  {name:14s} asked {value:<7g} readback {cap.get(prop):g}")
    print()
    return cap, got


def compute_signal(gray, background):
    """Brightness above the background. Saturating subtract, so only things
    BRIGHTER than the background survive - which is all we care about."""
    if background is None:
        return gray
    return cv2.subtract(gray, background)


def pick_threshold(signal, adaptive, k, absolute):
    if not adaptive:
        return int(absolute)
    # Relative to the frame's own statistics, so a global exposure or gain
    # change moves mean and sigma together and the threshold rides along.
    return int(np.clip(signal.mean() + k * signal.std(), 5, 254))


def find_spot(signal, thr, min_area, max_area, use_area=True):
    """Return (mask, best_passing_blob, brightest_blob_overall, n_blobs).

    Two blobs come back on purpose. If the brightest thing in frame is not the
    one being tracked, the area filter is rejecting it and the HUD must say so
    rather than silently picking something else.
    """
    _, mask = cv2.threshold(signal, thr, 255, cv2.THRESH_BINARY)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)

    n, labels, stats, centroids = cv2.connectedComponentsWithStats(mask, 8)

    best = brightest = None
    for i in range(1, n):
        area = int(stats[i, cv2.CC_STAT_AREA])
        peak = int(signal[labels == i].max())
        blob = {"peak": peak, "area": area,
                "x": float(centroids[i][0]), "y": float(centroids[i][1]),
                "passed": (not use_area) or (min_area <= area <= max_area)}
        if brightest is None or peak > brightest["peak"]:
            brightest = blob
        if blob["passed"] and (best is None or peak > best["peak"]):
            best = blob
    return mask, best, brightest, max(0, n - 1)


def draw_hud(canvas, lines, best):
    if best is not None:
        x, y = int(best["x"]), int(best["y"])
        cv2.drawMarker(canvas, (x, y), (0, 255, 0), cv2.MARKER_CROSS, 30, 1)
        cv2.circle(canvas, (x, y), 14, (0, 255, 0), 1)
    for i, line in enumerate(lines):
        pos = (8, 20 + i * 18)
        cv2.putText(canvas, line, pos, cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 3)
        cv2.putText(canvas, line, pos, cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)


def main():
    args = parse_args()
    cap, (fw, fh) = open_camera(args)

    # Area defaults are quoted for 640x480; scale so a different mode does not
    # silently invalidate the tuning.
    scale = (fw * fh) / (640 * 480)
    min_area = args.min_area if args.min_area is not None else max(4, int(8 * scale))
    max_area = args.max_area if args.max_area is not None else int(5000 * scale)

    bg_f32 = None
    bg_mode = 0                  # index into BG_MODES
    adaptive = True
    k, thr_abs = args.k, args.threshold
    use_area = True
    raw_mode = False
    views = ("raw", "signal", "mask")
    view = 0
    frame_times = deque(maxlen=30)
    means = deque(maxlen=20)
    saved = 0

    while True:
        ok, frame = cap.read()
        if not ok:
            continue
        frame_times.append(time.time())
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY) if frame.ndim == 3 else frame
        means.append(float(gray.mean()))

        if bg_f32 is None:
            bg_f32 = gray.astype(np.float32)
        elif BG_MODES[bg_mode] == "rolling":
            cv2.accumulateWeighted(gray, bg_f32, args.bg_rate)
        background = None if BG_MODES[bg_mode] == "off" else cv2.convertScaleAbs(bg_f32)

        signal = compute_signal(gray, background)
        thr = pick_threshold(signal, adaptive, k, thr_abs)
        mask, best, brightest, n_blobs = find_spot(
            signal, thr, min_area, max_area, use_area)

        if raw_mode:
            y, x = np.unravel_index(int(np.argmax(gray)), gray.shape)
            best = brightest = {"peak": int(gray.max()), "area": 0,
                                "x": float(x), "y": float(y), "passed": True}

        shown = {"raw": gray, "signal": signal, "mask": mask}[views[view]]
        canvas = cv2.cvtColor(shown, cv2.COLOR_GRAY2BGR)

        fps = 0.0
        if len(frame_times) > 1:
            span = frame_times[-1] - frame_times[0]
            if span > 0:
                fps = (len(frame_times) - 1) / span

        if raw_mode:
            lines = [f"BRIGHTEST-PIXEL MODE - nothing configurable   {fps:4.1f} fps",
                     f"peak raw {int(gray.max()):3d}   mean {gray.mean():5.1f}"]
        else:
            lines = [
                f"view {views[view]}   bg {BG_MODES[bg_mode]}   {fps:4.1f} fps",
                f"peak raw {int(gray.max()):3d}   after bg {int(signal.max()):3d}   "
                f"thr {thr}" + (f" (adaptive k={k:.1f})" if adaptive else " (absolute)"),
                f"area {min_area}-{max_area}" + ("" if use_area else " [OFF]")
                + f"   blobs {n_blobs}",
            ]
        lines.append(
            f"SPOT  {best['x']:.0f},{best['y']:.0f}  peak {best['peak']}  "
            f"area {best['area']}" if best else "no spot")

        if not raw_mode and brightest and (not best or brightest["peak"] > best["peak"]):
            why = "too big" if brightest["area"] > max_area else "too small"
            lines.append(f"!! brightest blob area {brightest['area']} "
                         f"peak {brightest['peak']} REJECTED: {why}")

        if len(means) == means.maxlen:
            lo, hi, avg = min(means), max(means), sum(means) / len(means)
            if avg > 1 and (hi - lo) / avg > 0.15:
                lines.append("(auto-exposure is drifting - rolling bg is absorbing it)")

        draw_hud(canvas, lines, best)
        cv2.imshow("ir spot tuner", canvas)
        key = cv2.waitKey(1) & 0xFF

        if key in (ord("q"), 27):
            break
        elif key == ord("p"):
            raw_mode = not raw_mode
        elif key == ord("b"):
            bg_mode = (bg_mode + 1) % len(BG_MODES)
        elif key == ord("c"):
            bg_f32 = None
        elif key == ord("t"):
            adaptive = not adaptive
        elif key == ord("m"):
            view = (view + 1) % len(views)
        elif key == ord("["):
            if adaptive:
                k = max(0.5, k - 0.5)
            else:
                thr_abs = max(1, thr_abs - 2)
        elif key == ord("]"):
            if adaptive:
                k += 0.5
            else:
                thr_abs = min(254, thr_abs + 2)
        elif key == ord("a"):
            use_area = not use_area
        elif key == ord("-"):
            max_area = max(min_area + 1, int(max_area * 0.7))
        elif key == ord("="):
            max_area = int(max_area * 1.4) + 1
        elif key == ord(","):
            min_area = max(1, min_area - 1)
        elif key == ord("."):
            min_area = min(max_area - 1, min_area + 1)
        elif key == ord("s"):
            name = f"irtest-{saved:03d}.png"
            cv2.imwrite(name, canvas)
            print(f"saved {name}")
            saved += 1

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
