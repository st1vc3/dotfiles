#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

ln -sfn "$DIR" ~/.dotfiles

# Fetch flake inputs as the real user before going root: the wallpaper input
# is fetched over SSH with this user's key, which root's ssh can't use.
# Usually the inputs are already in the store, but this guards against
# garbage collection or freshly updated inputs.
nix flake archive ~/.dotfiles

# Use the darwin-rebuild installed by the first switch. `nix run nix-darwin`
# would resolve through the flake registry to an unpinned master checkout and
# execute it as root; the installed tool matches what flake.lock pinned.
sudo darwin-rebuild switch --flake ~/.dotfiles#mac

"$DIR/check-skhd.sh"
