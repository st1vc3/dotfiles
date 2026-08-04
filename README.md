# macosx

Watch the walkthrough: https://youtu.be/5N-okeDdIuI

My personal Mac setup, managed with nix-darwin and home-manager.
One repo and one command reproduce the Nix-managed configuration on a fresh Mac.
Homebrew applications are declared by name but follow the versions available in Homebrew when activation runs.

## Contributing / Using This Repo

These are my personal dotfiles, shared publicly so people can read them, learn from them, and fork them freely.
Feature requests and pull requests aren't accepted here - fork it and make it yours instead.
If you hit a genuine bug, feel free to open a GitHub Issue.

## What you get

Running the switch builds:

- System settings (dark mode, key repeat, dock, Finder, trackpad)
- Homebrew apps and CLI tools (ripgrep, fd, fzf, jq, git, gh, Neovim, Hack Nerd Font, and more)
- Shell (zsh, aliases, starship prompt)
- Editor (Neovim config with the rose-pine moon theme)
- Agent configs (Claude, Codex, opencode all share one AGENTS.md)
- Tiling window manager (AeroSpace) with skhd hotkeys, a red active-window border, and left Option as the mod key
- Desktop status bar (Übersicht Simple Bar) showing AeroSpace workspaces and system status

## Prerequisites

- Apple Silicon Mac.
- A GitHub SSH key in `~/.ssh`, placed manually before running `bootstrap.sh`.
  The `wallpaper` flake input is a private repo fetched over SSH, so the pre-fetch step fails without a key GitHub accepts (forks: see "Make it yours" below).

## Fresh-machine setup

On a brand new Mac, from a bare clone of this repo:

```sh
git clone https://github.com/st1vc3/macosx.git
cd macosx
```

On a truly blank Mac, this `git clone` may itself pop up the "install Command Line Developer Tools" dialog, since `git` is a CLT shim. Click Install and wait for it to finish before continuing - `bootstrap.sh` also checks for this later, but the earliest trigger point is whichever command you run first.

Before you run it: review "Make it yours" below.
Change the host label if needed, and read the Homebrew cleanup warning.
`bootstrap.sh` applies the config to your machine, so do this first.

```sh
./bootstrap.sh
```

`bootstrap.sh` runs these steps, in order:

1. Installs Xcode Command Line Tools, if they aren't already installed.
   Homebrew needs these later; checking here means the GUI installer prompt (if any) happens up front with context, not buried mid-way through Homebrew's own bootstrap.
2. Installs a pinned, checksum-verified Determinate Nix release, if Nix isn't already installed.
3. Symlinks this repo to `~/.dotfiles`.
   This has to happen before the first build, because `home.nix` points at config files through `~/.dotfiles`.
4. Checks the `user` configured in `flake.nix` against your actual macOS username, and offers to fix it for you if they differ.
5. Pre-fetches the flake inputs as your user, so the private wallpaper repo is fetched with your SSH key (root's ssh can't use it).
6. Runs the first `darwin-rebuild switch`.
   It fetches the `darwin-rebuild` tool from the nix-darwin 26.05 release branch, then applies this repo's locked flake config.
7. Launches Zen once (if it's installed and has never run) so it creates its profile, then re-runs the switch so the uBlock Origin and SponsorBlock extensions land in that profile.
8. Starts AeroSpace for the first time.
   Grant it Accessibility when macOS asks; `start-at-login = true` in `aerospace.toml` takes over from then on.
9. Runs `check-skhd.sh`, which verifies skhd is actually running and walks you through its one-time Accessibility grant if it isn't.
   `rebuild.sh` runs the same check after every switch, because the grant is tied to skhd's exact `/nix/store` path and breaks whenever a rebuild changes it.

After that, `darwin-rebuild` exists and you're on the normal workflow below.

### Validate without applying

Once Nix is installed (`bootstrap.sh` step 2 handles that), you can check that the config builds without touching your system - handy when you have edited something:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

If you renamed the host label in "Make it yours", substitute your label for `mac` in these commands.

CI runs these same checks (plus shellcheck on the scripts) on every push to `main` - see `.github/workflows/ci.yml`.
Since CI can't reach the private wallpaper repo, the workflow substitutes the stub in `.github/wallpaper-stub/` for that input.

## Daily use

Edit the config files in place, then apply:

```sh
./rebuild.sh
```

That's it.
No separate build-and-copy step.

## Window management and hotkeys

AeroSpace tiles the windows, but binds no keys itself.
All hotkeys live in skhd (`home/.config/skhd/skhdrc`), which calls the `aerospace` CLI.

Why the split: this is a German (ISO) keyboard, where Option types essential characters (`@` via Option+L, brackets via Option+5..9, `€`, `~`).
AeroSpace cannot tell the two Option keys apart, so binding `alt` anything swallows those characters.
skhd can: everything is bound to `lalt`, so the LEFT Option is the mod key and the RIGHT Option keeps typing characters.

| Keys | Action |
| --- | --- |
| left Opt+Return | new kitty window on workspace 1 |
| left Opt+Shift+Return | kitty running herdr on workspace 1 |
| left Opt+S | workspace B, launch/focus Zen |
| left Opt+H/J/K/L | focus window left/down/up/right |
| left Opt+Shift+H/J/K/L | move window |
| left Opt+1..4/B/C | switch workspace |
| left Opt+Shift+1..4/B/C | move window to workspace |
| left Opt+Tab | previous workspace |
| left Opt+F | toggle floating |
| left Opt+R | flatten layout |
| Ctrl+left Opt+H/J/K/L | join with neighbour |
| Ctrl+left Opt+Backspace | close all windows but current |

Window rules pin kitty to workspace 1, Zen/Safari to workspace B, and Telegram/WhatsApp to workspace C (`home/.config/aerospace/aerospace.toml`).
Both configs hot-reload on save; no rebuild needed for binding tweaks.

Simple Bar is pinned by `flake.lock`, installed into Übersicht's widget directory, and configured through `home/.simplebarrc`.
The AeroSpace config reserves the bar's top gap and refreshes it on focus and workspace changes.
Its settings are declarative, so edit `home/.simplebarrc` and rebuild instead of changing them through Simple Bar's settings window.

If hotkeys ever go deaf while skhd is still running (it can grab a dead event tap when the input stack churns underneath it, e.g. during login or driver changes), restart it:

```sh
launchctl kickstart -k gui/$UID/org.nixos.skhd
```

Both AeroSpace and skhd need a one-time Accessibility grant (System Settings -> Privacy & Security -> Accessibility).
`bootstrap.sh` triggers both: it launches AeroSpace once (macOS prompts for the grant) and runs `check-skhd.sh`, which detects a missing skhd grant and walks you through it.
skhd's grant is tied to its exact `/nix/store` path, so it breaks whenever a rebuild changes that path - `rebuild.sh` re-runs `check-skhd.sh` after every switch to catch that, and you can run it standalone whenever hotkeys go deaf.

## Make it yours

This repo is mine.
If you clone it, review these before you run `bootstrap.sh`:

- **Username**: run `./bootstrap.sh` (it detects your macOS username and offers to set it) OR change the single `user = "stivce"` line in `flake.nix`.
  Everything else (`configuration.nix`, `home.nix`, home directory paths) is threaded from that one variable.
- **Host label** `"mac"`, in three places: `flake.nix` (the `darwinConfigurations."mac"` name), `rebuild.sh` (the `#mac` at the end of the flake reference), and `bootstrap.sh`'s first-switch command (also `#mac`).
  All three have to match.
- **Wallpaper**: the `wallpaper` input in `flake.nix` points at my *private* repo over SSH, so a fork can't fetch it - `bootstrap.sh` would fail at the pre-fetch step with an SSH permission error.
  Either point that input at your own repo of images (and update the image path in `configuration.nix`'s `postActivation` script), or remove the wallpaper setup entirely: the `wallpaper` input and the two `wallpaper` references in `flake.nix`, plus the `postActivation` block in `configuration.nix`.

**Git identity:** `home.nix` sets *my* git identity declaratively (`programs.git.settings.user` - the name `st1vc3` and my GitHub noreply email).
If you clone this repo, change those two lines to your own name and email, or delete the `user` block entirely and git will stop your first commit and tell you what to set.

**Homebrew cleanup warning:** `configuration.nix` sets `homebrew.onActivation.cleanup = "zap"`.
That means every time you switch, Homebrew removes any package or cask on your machine that isn't listed in the `brews` and `casks` arrays in `configuration.nix`.
If you already have Homebrew stuff installed that isn't in that list, the first switch will uninstall it.
Read through `brews` and `casks` before you run `bootstrap.sh` or `rebuild.sh` for the first time, and add anything you want to keep.

**About `herdr`:** it's in the `brews` list.
It's a real public Homebrew formula (`brew info herdr` finds it in homebrew-core, no tap needed), so it will install fine.
If you don't use it, just remove it from `brews` in your copy.

**Heads-up:**

- `home/AGENTS.md` is my personal agent policy, and `home.nix` installs it for Claude, Codex, and opencode.
  If you clone this repo, you'd silently inherit my agent instructions - edit or delete `home/AGENTS.md` if you don't want that.
- The `cc` and `co` shell aliases in `home.nix` are high-agency shortcuts: `claude --dangerously-skip-permissions` and `codex --full-auto`.
  Claude's settings also suppress the dangerous-mode permission reminder.
  They're convenient for me, but know what they do before you use them.
- GitHub HTTPS URLs are globally rewritten to SSH by `programs.git.settings.url` in `home.nix`.
  This matches the machine's authentication setup and also means tools such as lazy.nvim fetch GitHub repositories over SSH.

## Repo tour

- `flake.nix` - the entry point.
  Wires up nixpkgs, nix-darwin, home-manager, and nix-homebrew, and declares the `mac` machine.
- `configuration.nix` - system-level config: macOS defaults, Homebrew.
- `home.nix` - user-level config: shell, packages, prompt, and the symlinks described below.
- `bootstrap.sh` - one-time setup for a fresh Mac: installs the Command Line Tools and Nix, then runs the first switch (see "Fresh-machine setup" above).
- `rebuild.sh` - re-applies the config after the first switch.
  Run this every time you make a change.
- `check-skhd.sh` - verifies skhd is actually running and walks through its Accessibility grant.
  Runs automatically at the end of `bootstrap.sh` and `rebuild.sh`; run it standalone whenever hotkeys go deaf.
- `home/` - the actual config files that get symlinked into place (Neovim, kitty, AeroSpace, skhd, herdr, Claude settings, the shared `AGENTS.md`).

## How the symlinks work

The durable configuration files under `home/` are the real files - editing them here is editing your live config, no rebuild needed to see the change in your editor.
`home.nix` uses `mkOutOfStoreSymlink` to point paths like `~/.config/nvim` straight at this repo, so the two never drift out of sync.
For Herdr, only `config.toml` is linked; logs, sockets, release notes, and session state stay outside the repository.
You only run `./rebuild.sh` when you change something that isn't just a symlinked file, like a package list or a system default.

## Notes

The first time you launch `nvim`, it bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub.
That needs network access once; after that it's offline.
Neovim keeps italics off and uses a transparent background on macOS, Windows, and WSL so it matches the terminal setup.

## License

This repo is licensed under MIT No Attribution.
See `LICENSE`.
