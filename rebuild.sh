#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "Error: ~/.dotfiles exists and is not a symbolic link. Move it, then rerun rebuild.sh." >&2
  exit 1
fi
ln -sfn "$DIR" "$HOME/.dotfiles"

nix flake archive ~/.dotfiles

sudo darwin-rebuild switch --flake ~/.dotfiles#mac

"$DIR/check-skhd.sh"
