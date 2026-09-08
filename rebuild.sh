#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=host.sh
. "$DIR/host.sh"

if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "Error: ~/.dotfiles exists and is not a symbolic link. Move it, then rerun rebuild.sh." >&2
  exit 1
fi
ln -sfn "$DIR" "$HOME/.dotfiles"

HOST="$(resolve_host "${1:-}")"
echo "==> Building host '$HOST'"

nix flake archive "$HOME/.dotfiles"

sudo darwin-rebuild switch --flake "$HOME/.dotfiles#$HOST"

"$DIR/check-skhd.sh"
