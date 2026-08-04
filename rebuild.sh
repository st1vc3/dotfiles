#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

ln -sfn "$DIR" ~/.dotfiles

nix flake archive ~/.dotfiles

sudo darwin-rebuild switch --flake ~/.dotfiles#mac

"$DIR/check-skhd.sh"
