# Project notes for agents

Deliberate decisions in this repo - do NOT silently revert them:

- `homebrew.onActivation.cleanup = "zap"` in `hosts/common.nix` is intentional. It forces the good habit of declaring every Homebrew package in the Nix config instead of installing things ad-hoc, which keeps the machine reproducible. Do not soften it to `uninstall` or `none`. Users are warned about its effect in README.md; this note is for anyone tempted to change the setting itself.
- Host accounts come from the private `dotfiles-private` flake input, never from this repository, and evaluation stays pure. Do not reintroduce `builtins.getEnv` or `--impure`, and do not inline an account name here to "simplify" it.
- Nothing in the private input is a secret. Flake inputs land in `/nix/store`, which is world-readable on the fetching machine. Credentials belong in the untracked `.env` or the Keychain, never in a flake input.
- `vpn.sh` runs its own `_hook` subcommand as root, via openconnect. That path must never read `.env`, which is user-writable. Keep `load_config` out of it.
- `url."git@github.com:".pushInsteadOf` in `modules/home/shell.nix` is deliberately `pushInsteadOf`, not `insteadOf`. Rewriting fetches breaks tooling that clones from GitHub over HTTPS without a key loaded.
- `statix.toml` disables `repeated_keys`. That rule fights the dotted-option style every nix-darwin and Home Manager module here uses.
- Never commit `.no-mistakes/` validation evidence. `.no-mistakes/` is gitignored; if a validation pipeline stages evidence into a branch, drop it before merging.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
