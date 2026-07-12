#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

ln -sfn "$DIR" ~/.dotfiles

exec sudo nix \
  --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake ~/.dotfiles#mac
