#!/usr/bin/env bash
# Install the wall as systemd user services, so the Pi boots into it.
#
# User services, not system ones, because the wall needs the graphical session
# to exist: the browser talks to the compositor, and WAYLAND_DISPLAY only means
# anything inside that session. The Pi already autologins, so the session comes
# up at boot and these come up with it - no linger and no sudo required.
set -euo pipefail
cd "$(dirname "$0")/../.."
REPO="$(pwd)"
UNITS="$HOME/.config/systemd/user"

mkdir -p "$UNITS"
for u in irtracker irkiosk; do
    sed "s#%h#$HOME#g" "tools/pi/$u.service" > "$UNITS/$u.service"
    echo "installed $UNITS/$u.service"
done

systemctl --user daemon-reload
systemctl --user enable irtracker.service irkiosk.service
echo
echo "Enabled. Start now with:"
echo "    systemctl --user restart irtracker irkiosk"
echo "Logs:"
echo "    tail -f $REPO/tracker.log $REPO/kiosk.log"
