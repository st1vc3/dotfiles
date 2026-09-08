#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [ -e "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]; then
  echo "Error: ~/.dotfiles exists and is not a symbolic link. Move it, then rerun rebuild.sh." >&2
  exit 1
fi
ln -sfn "$DIR" "$HOME/.dotfiles"

# The account name is machine-specific and lives in the untracked .env, so the
# flake reads it from the environment. That makes evaluation impure, and sudo
# scrubs the environment, so the value is passed through explicitly.
if [ -r "$DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091 # path is derived at runtime, not checkable here
  . "$DIR/.env"
  set +a
fi

nix flake archive ~/.dotfiles

sudo DOTFILES_USER="${DOTFILES_USER:-}" DOTFILES_WORK_MACHINE="${DOTFILES_WORK_MACHINE:-false}" \
  darwin-rebuild switch --flake ~/.dotfiles#mac --impure

"$DIR/check-skhd.sh"
