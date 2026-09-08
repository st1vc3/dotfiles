#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/org.nixos.skhd.plist"
SERVICE="gui/$(id -u)/org.nixos.skhd"

echo "==> Checking that skhd hotkeys are live"

if [ ! -f "$PLIST" ]; then
  echo "skhd launch agent not installed (services.skhd disabled?), skipping check"
  exit 0
fi

SKHD_BIN="$(plutil -extract ProgramArguments.0 raw -o - "$PLIST")"

# Home Manager's reloadSkhd activation kickstarts the service just before this
# script runs, so a freshly restarted skhd may not have a pid yet. Poll instead
# of sampling once, otherwise a healthy service reads as dead.
skhd_running() {
  local deadline=$((SECONDS + ${1:-5}))
  while true; do
    if launchctl print "$SERVICE" 2>/dev/null | grep -q "pid = "; then
      return 0
    fi
    [ "$SECONDS" -lt "$deadline" ] || return 1
    sleep 1
  done
}

kick_skhd() {
  launchctl bootout "$SERVICE" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
}

# Only tear the service down when it is actually broken. Doing it on every
# rebuild killed working hotkeys for a few seconds for no reason.
if skhd_running 5; then
  echo "skhd is running - hotkeys are live"
  exit 0
fi

echo "skhd is not running - restarting it"
kick_skhd

if skhd_running 5; then
  echo "skhd is running - hotkeys are live"
  exit 0
fi

cat <<EOM

============================================================
  skhd is NOT running - your hotkeys are dead.

  macOS requires a one-time Accessibility grant that no
  script can perform. In the System Settings pane that just
  opened (Privacy & Security -> Accessibility):

    1. Click "+"
    2. Press Cmd+Shift+G and paste this exact path:

       $SKHD_BIN

    3. Add it and make sure its toggle is ON.

  If an older skhd entry is already listed, remove it first:
  the grant is tied to the exact /nix/store path, so it
  breaks whenever a rebuild changes skhd's store path.
============================================================

EOM
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true

if [ -t 0 ]; then
  while true; do
    read -r -p "Press Enter once you granted access (Ctrl-C to give up)... " _
    kick_skhd
    if skhd_running 5; then
      echo "skhd is running - hotkeys are live"
      exit 0
    fi
    echo "skhd still isn't running - is the toggle ON and the path exactly the one above?"
  done
fi
exit 1
