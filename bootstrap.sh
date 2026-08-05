#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
NIX_INSTALLER_VERSION="v3.21.0"
NIX_INSTALLER_SHA256="c3cf066a28941e89fa1e38ed36f2acfc7479f9b088ddcf35160362a5ee89bd43"
NIX_INSTALLER_TMP=""

echo "==> Requesting sudo access up front"
sudo -v
while true; do sudo -n true; sleep 60; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
cleanup() {
  pkill -P "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  if [ -n "$NIX_INSTALLER_TMP" ]; then
    rm -f "$NIX_INSTALLER_TMP"
  fi
}
trap cleanup EXIT

echo "==> Step 1: Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "    already installed, skipping"
else
  echo "    not found, triggering the installer (a GUI dialog will appear - click Install)"
  xcode-select --install
  echo "    waiting for the installation to finish..."
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
  echo "    done"
fi

echo "==> Step 2: Determinate Nix"
NIX_PROFILE_SH=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
elif [ -e "$NIX_PROFILE_SH" ]; then
  echo "    nix already installed but not on this shell's PATH, loading it"
  PATH="/nix/var/nix/profiles/default/bin:$PATH"
else
  while IFS= read -r vol; do
    [ -n "$vol" ] || continue
    mp="$(diskutil info "$vol" 2>/dev/null | sed -nE 's/.*Mount Point:[[:space:]]*//p')"
    if [ -z "$mp" ] || [ "$mp" = "Not Mounted" ]; then
      echo "    found unmounted 'Nix Store' volume: $vol"
      diskutil info "$vol" | sed -nE '/Device Identifier|Volume Name|Disk Size|APFS Volume Disk/p'
      read -r -p "    Permanently delete this stale volume? [y/N] " REPLY
      if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
        sudo diskutil apfs deleteVolume "$vol"
      else
        echo "    Refusing to delete $vol. Resolve it manually, then rerun bootstrap.sh." >&2
        exit 1
      fi
    fi
  done < <(diskutil list 2>/dev/null | awk '/Nix Store/ {print $NF}')

  NIX_INSTALLER_TMP="$(mktemp -t determinate-nix-installer.XXXXXX)"
  curl --proto '=https' --tlsv1.2 -sSfL \
    "https://install.determinate.systems/nix/tag/${NIX_INSTALLER_VERSION}/nix-installer.sh" \
    -o "$NIX_INSTALLER_TMP"
  echo "${NIX_INSTALLER_SHA256}  ${NIX_INSTALLER_TMP}" | shasum -a 256 -c -
  sh "$NIX_INSTALLER_TMP" install --no-confirm
  rm -f "$NIX_INSTALLER_TMP"
  NIX_INSTALLER_TMP=""
  PATH="/nix/var/nix/profiles/default/bin:$PATH"
fi

echo "==> Step 3: symlink this repo to ~/.dotfiles"
if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "Error: ~/.dotfiles exists and is not a symbolic link. Move it, then rerun bootstrap.sh." >&2
  exit 1
fi
ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 4: personalize the configured username"
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

NIX_BIN="$(command -v nix)"

echo "==> Step 5: pre-fetch flake inputs as $REAL_USER"
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
  "$NIX_BIN" flake archive ~/.dotfiles

echo "==> Step 6: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac

echo "==> Step 7: Zen browser profile"
if [ -d "/Applications/Zen.app" ]; then
  PROFILES_INI="$HOME/Library/Application Support/zen/profiles.ini"
  if [ ! -f "$PROFILES_INI" ]; then
    echo "    Zen hasn't been launched yet - opening it now to create its profile."
    open -a Zen
    read -r -p "    Once Zen has fully started, quit it completely, then press Enter to continue... " _
    echo "    Re-running darwin-rebuild switch so the extensions land in the new profile"
    sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
      switch --flake ~/.dotfiles#mac
  fi
else
  echo "    Zen not installed, skipping"
fi

echo "==> Step 8: start AeroSpace"
if [ -d "/Applications/AeroSpace.app" ]; then
  if pgrep -xq AeroSpace; then
    echo "    already running, skipping"
  else
    echo "    launching AeroSpace - grant Accessibility when macOS asks."
    echo "    start-at-login in aerospace.toml takes over from the next login on."
    open -a AeroSpace
  fi
else
  echo "    AeroSpace not installed, skipping"
fi

echo "==> Step 9: skhd Accessibility grant"
"$DIR/check-skhd.sh"

echo "==> Done. Use ./rebuild.sh for future changes."
