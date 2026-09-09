#!/usr/bin/env bash
# Boot the wall with no network, without turning off the router - and without
# locking yourself out of a Pi that has no keyboard.
#
# The software side needs no network and that is already proven: the page makes
# exactly one request, for itself, from localhost, and nothing in the boot path
# depends on a network target. What this tests is the part that cannot be
# reasoned about - how the OS behaves coming up with no network at all.
#
# THE SAFETY PROPERTY: the restore is armed, and verified armed, BEFORE the
# radio goes off. It runs from a boot-time user timer, so it fires even if the
# test hangs, even if you power-cycle mid-test, and even if nobody is watching.
# The worst case is that you wait out the timer.
#
#   ./wifi-test.sh check          are the permissions in place?
#   ./wifi-test.sh start [min]    arm restore (default 12 min), wifi off, reboot
#   ./wifi-test.sh stop           restore now and disarm
set -uo pipefail

UNIT="$HOME/.config/systemd/user"
NM=/usr/bin/nmcli
say() { echo "[wifi-test] $*"; }

# Ask sudo what is PERMITTED rather than running something to find out: the
# rule grants "nmcli radio wifi on|off", and testing with a bare "nmcli radio
# wifi" fails even when the rule is correctly installed.
perms_ok() {
    sudo -n -l "$NM" radio wifi on >/dev/null 2>&1 \
        && sudo -n -l /sbin/reboot >/dev/null 2>&1
}

usage_perms() {
    cat <<EOF
This needs to toggle the radio and reboot without a password, or it cannot
restore itself unattended. Run these two lines once (they will ask for your
password), then try again:

  echo '$USER ALL=(root) NOPASSWD: $NM radio wifi on, $NM radio wifi off, /sbin/reboot' \\
      | sudo tee /etc/sudoers.d/wall-wifi-test
  sudo chmod 0440 /etc/sudoers.d/wall-wifi-test

Remove it afterwards with:

  sudo rm /etc/sudoers.d/wall-wifi-test
EOF
}

arm() {
    local mins="$1"
    mkdir -p "$UNIT"
    cat > "$UNIT/wall-wifi-restore.service" <<EOF
[Unit]
Description=Restore wifi after the no-network test
[Service]
Type=oneshot
ExecStart=/usr/bin/sudo -n $NM radio wifi on
ExecStartPost=/usr/bin/systemctl --user disable wall-wifi-restore.timer
EOF
    cat > "$UNIT/wall-wifi-restore.timer" <<EOF
[Unit]
Description=Restore wifi ${mins} minutes after boot
[Timer]
OnBootSec=${mins}min
OnActiveSec=${mins}min
AccuracySec=5s
[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now wall-wifi-restore.timer >/dev/null 2>&1
    systemctl --user is-enabled wall-wifi-restore.timer >/dev/null 2>&1
}

case "${1:-check}" in
check)
    if perms_ok; then say "permissions OK - 'start' will work unattended"
    else say "permissions missing"; echo; usage_perms; exit 1; fi
    say "radio is currently: $(nmcli radio wifi)"
    ;;

start)
    mins="${2:-12}"
    perms_ok || { say "permissions missing"; echo; usage_perms; exit 1; }

    say "arming restore for ${mins} minutes after boot"
    arm "$mins" || { say "could not arm the restore timer - NOT touching the radio"; exit 1; }
    # Verified armed, or we stop here. This is the whole safety argument.
    systemctl --user is-enabled wall-wifi-restore.timer >/dev/null 2>&1 \
        || { say "timer did not enable - NOT touching the radio"; exit 1; }
    say "restore timer armed and enabled"

    say "radio off, then rebooting into a networkless boot"
    say "you will lose ssh; it comes back ~${mins} min after the Pi boots"
    sudo -n $NM radio wifi off || { say "could not disable wifi"; exit 1; }
    sleep 1
    sudo -n /sbin/reboot
    ;;

stop)
    systemctl --user disable --now wall-wifi-restore.timer >/dev/null 2>&1
    if perms_ok; then sudo -n $NM radio wifi on && say "radio on, timer disarmed"
    else say "run: sudo nmcli radio wifi on"; fi
    ;;

*) sed -n '2,20p' "$0" ;;
esac
