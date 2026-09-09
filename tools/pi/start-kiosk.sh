#!/usr/bin/env bash
# Bring the wall up on the TV, then put it straight into calibration.
#
# Calibration is not optional and not remembered: the homography lives in the
# page, so a reboot always needs it redone. Rather than leave a wall that looks
# alive but paints nothing, this ends at the corner targets every time.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
OUTPUT="${WALL_OUTPUT:-}"           # empty = pick the first connected output
MODE="${WALL_MODE:-}"               # empty = try 720p, then 1080p
URL="${WALL_URL:-http://localhost:8000/wall.html}"   # WALL_URL=…/test-wall.html for the old one
WS="${WALL_WS:-ws://localhost:8765}"

say() { echo "[start-kiosk] $(date +%H:%M:%S) $*"; }

# 1. The compositor may not be up yet - we are started at login, alongside it.
for _ in $(seq 1 60); do
    [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] && break
    sleep 1
done
[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] || { say "no wayland socket, giving up"; exit 1; }

# 2. Resolution is the wall's frame rate: measured ~10 fps at 1440p, ~15 at
#    1080p and 34+ at 720p, because the cost is pure fill rate. wlr-randr does
#    not persist, so this runs every boot.
#
#    The output is DETECTED, not assumed. A different TV, or the other HDMI
#    port, would otherwise leave the mode unset - and a 4K panel at its native
#    mode is nine times the pixels of 720p, which would look like the software
#    had broken rather than the display having changed.
if [ -z "$OUTPUT" ]; then
    OUTPUT=$(wlr-randr 2>/dev/null | awk '/^[A-Za-z]/{n=$1} /Enabled: yes/{print n; exit}')
fi
[ -n "$OUTPUT" ] || OUTPUT=HDMI-A-1
say "display output: $OUTPUT"

set_mode() { wlr-randr --output "$OUTPUT" --mode "$1" >/dev/null 2>&1; }
if [ -n "$MODE" ]; then
    set_mode "$MODE" || say "could not set $MODE on $OUTPUT"
elif set_mode 1280x720@60; then say "mode 1280x720@60"
elif set_mode 1920x1080@60; then say "mode 1920x1080@60 (720p refused)"
else say "WARNING: could not set a mode on $OUTPUT - running at its native one"
fi

# 3. Wait for the tracker's HTTP server - it serves the page we are about to open.
for _ in $(seq 1 60); do
    curl -sf -o /dev/null "$URL" && break
    sleep 1
done

say "launching chromium"
chromium \
    --ozone-platform=wayland --kiosk \
    --password-store=basic --use-mock-keychain \
    --noerrdialogs --disable-infobars --disable-session-crashed-bubble \
    --no-first-run --disable-features=Translate \
    --autoplay-policy=no-user-gesture-required \
    --remote-debugging-port=9222 --remote-allow-origins='*' \
    --user-data-dir="$HOME/.config/chromium-kiosk" \
    "$URL" &
CHROME=$!

# 4. Wait for the page to answer over CDP, then wire it up. Chromium reports a
#    debugging port before the page exists, so poll the page itself.
for _ in $(seq 1 90); do
    python3 tools/pi/kiosk.py '1' >/dev/null 2>&1 && break
    sleep 1
done

if python3 tools/pi/kiosk.py --connect "$WS" >/dev/null 2>&1; then
    say "connected to $WS"
    sleep 2
    if python3 tools/pi/kiosk.py --calibrate >/dev/null 2>&1; then
        say "calibration started - aim at the four corners"
    else
        say "could not start calibration"
    fi
else
    say "could not reach the tracker at $WS"
fi

wait "$CHROME"
