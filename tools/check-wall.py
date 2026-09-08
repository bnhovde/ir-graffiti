#!/usr/bin/env python3
"""Structural sanity check for test-wall.html. Run it after every merge.

One merge of the wall produced three separate silent breakages, none of which
a syntax check catches:

  * `class IRTracker` declared twice - a SyntaxError, so nothing ran at all.
  * A method block spliced into the middle of another method, dropping three
    methods entirely. Valid syntax; failed only when calibration was started.
  * `function applyHomography` declared twice. Duplicate FUNCTION declarations
    are legal and the last one silently wins - and the two versions returned
    different shapes, so the app painted at NaN while reporting success.

The third is the dangerous one: the case JavaScript does not complain about is
exactly the case that needs checking. Counting occurrences of a name is not
enough - a corrupted method still contains its own name.

    ./tools/check-wall.py [path]        exit 1 if anything is wrong
"""
import re
import sys

REQUIRED = [
    ("class PiTracker", "Pi tracking"),
    ("solveHomography", "4-corner calibration"),
    ("canEmaAlpha", "cursor smoothing is tunable"),
    ("_ovRect", "overlay dirty-rect fix"),
    ("liveStamps && t.liveStamps", "overlay ghost fix"),
    ("window.app =", "CDP access - the Pi has no mouse or keyboard"),
]
# Methods the Pi path needs whole, not merely mentioned.
METHODS = ["runCanLoop", "onCanFrame", "beginIRCalibration", "endIRCalibration",
           "toggleIRDiagnostics", "startPreviewPump", "setCamMode", "activeTracker"]


def main(path="test-wall.html"):
    html = open(path).read()
    blocks = re.findall(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", html, re.S)
    if not blocks:
        print("FAIL: no inline script found"); return 1
    js = max(blocks, key=len)
    lines = js.split("\n")
    bad = []

    classes = re.findall(r"^class (\w+)", js, re.M)
    for c in sorted({c for c in classes if classes.count(c) > 1}):
        bad.append(f"class {c} declared {classes.count(c)}x - SyntaxError, nothing will run")

    funcs = {}
    for i, l in enumerate(lines):
        m = re.match(r"^(?:async )?function (\w+)", l)
        if m:
            funcs.setdefault(m.group(1), []).append(i + 1)
    for name, at in funcs.items():
        if len(at) > 1:
            bad.append(f"function {name} declared {len(at)}x at {at} - "
                       "legal, last wins silently, shapes may differ")

    # Methods, scoped to their class, and required to be structurally whole.
    cls, seen = None, {}
    for i, l in enumerate(lines):
        m = re.match(r"^class (\w+)", l)
        if m:
            cls = m.group(1); seen.setdefault(cls, {})
        m = re.match(r"^  (?:async )?(\w+)\s*\(", l)
        if m and cls and m.group(1) not in ("if", "for", "while", "switch", "catch", "return"):
            seen[cls].setdefault(m.group(1), []).append(i + 1)
    for c, ms in seen.items():
        for n, at in ms.items():
            if len(at) > 1:
                bad.append(f"{c}.{n} defined {len(at)}x at {at} - last wins silently")

    app = seen.get("PaintApp", {})
    for n in METHODS:
        if n not in app:
            bad.append(f"PaintApp.{n} is missing - a merge may have swallowed it")

    for probe, why in REQUIRED:
        if probe not in js:
            bad.append(f"missing: {why}  ({probe!r})")

    if bad:
        print(f"FAIL ({len(bad)}):")
        for b in bad:
            print("  -", b)
        return 1
    print(f"OK  {len(classes)} classes, {len(funcs)} top-level functions, "
          f"{len(app)} PaintApp methods")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
