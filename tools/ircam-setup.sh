#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Manual exposure/gain/focus for the C910 via uvcc.
#
# KNOWN NOT TO WORK ON THIS MAC. uvcc enumerates the camera fine, but every UVC
# control transfer hangs, and `uvcc ranges` reports min 0 / max 0 for every
# control - libusb can see the descriptor but macOS's own UVC driver owns the
# control interface and will not release it. Verified 2026-08-30.
#
# Kept because it works on Linux, and on macOS it at least fails fast now
# instead of hanging. If you want manual control on macOS the practical answer
# is the "Webcam Settings" app; otherwise irtest.py is built to not need it.
# ---------------------------------------------------------------------------
set -uo pipefail

VENDOR=${VENDOR:-1133}      # 0x046d Logitech
PRODUCT=${PRODUCT:-2081}    # 0x0821 C910
EXPOSURE=${EXPOSURE:-1250}  # units of 100 us
GAIN=${GAIN:-255}
FOCUS=${FOCUS:-0}           # 0 = infinity
TIMEOUT=${TIMEOUT:-6}

command -v uvcc >/dev/null 2>&1 || {
    echo "uvcc not installed:  npm install -g uvcc"; exit 1; }

# macOS has no coreutils timeout, and a hung uvcc will sit there forever.
run() {
    "$@" & local pid=$!
    ( sleep "$TIMEOUT"; kill -9 $pid 2>/dev/null ) & local watcher=$!
    wait $pid 2>/dev/null; local rc=$?
    kill -9 $watcher 2>/dev/null
    return $rc
}

uvc() { run uvcc --vendor "$VENDOR" --product "$PRODUCT" "$@" 2>/dev/null; }

echo "C910 manual setup"
if ! uvc get auto_exposure_mode >/dev/null; then
    cat <<'MSG'
  uvcc cannot reach this camera's controls - the call timed out.
  This is the macOS limitation described at the top of this script, not a bug
  in your setup. Exposure and gain will stay on auto.

  irtest.py handles that: its background is a rolling average that tracks
  exposure drift, and its threshold is relative to each frame's own statistics.
MSG
    exit 1
fi

for pair in "auto_exposure_mode 1" "absolute_exposure_time $EXPOSURE" \
            "gain $GAIN" "auto_focus 0" "absolute_focus $FOCUS" \
            "auto_white_balance 0"; do
    set -- $pair
    uvc set "$1" "$2" >/dev/null
    got=$(uvc get "$1" | tr -d '[:space:]')
    note="ok"; [ "${got:-x}" = "$2" ] || note="(asked for $2)"
    printf '  %-26s -> %-8s %s\n' "$1" "${got:-?}" "$note"
done
