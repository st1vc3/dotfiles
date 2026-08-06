# macosx

Declarative Apple Silicon macOS configuration built with nix-darwin, Home Manager, and Homebrew.

This repository manages system defaults, applications, command-line tools, shell configuration, development tools, browser settings, and a keyboard-driven desktop environment. It is a personal setup published as a reference and starting point for forks.

## Requirements

- An Apple Silicon Mac
- Administrator access
- Internet access
- Xcode Command Line Tools
- A GitHub SSH key accepted by GitHub

The SSH key is required because the wallpaper flake input is a private repository. Forks must replace or remove that input before installation.

## Before installing

Review these machine-specific values:

- Change `user` in `flake.nix` if your macOS account is not `stivce`.
- Keep the host label consistent across `flake.nix`, `bootstrap.sh`, and `rebuild.sh` if you rename `mac`.
- Replace the private `wallpaper` input in `flake.nix`, or remove it together with the wallpaper activation in `configuration.nix`.
- Replace the Git identity in `modules/home/shell.nix`.
- Review `home/AGENTS.md`, which is installed for Claude, Codex, and opencode.
- Review the `cc`, `co`, and `cx` aliases in `modules/home/shell.nix`, since they run agents with reduced safety restrictions.

Homebrew activation uses `cleanup = "zap"`. Every formula and cask that should remain installed must be declared in `configuration.nix`. Undeclared Homebrew packages and applications are removed during activation.

## Fresh installation

Clone the repository:

```sh
git clone https://github.com/st1vc3/macosx.git
cd macosx
```

If macOS prompts to install the Command Line Tools, complete that installation before continuing. Then run:

```sh
./bootstrap.sh
```

The bootstrap process installs Nix when needed, links the repository at `~/.dotfiles`, validates the configured username, fetches the flake inputs, applies the system configuration, initializes Zen extensions, starts AeroSpace, and verifies skhd.

macOS may request Accessibility access for AeroSpace, skhd, and Hammerspoon. Grant it under System Settings > Privacy & Security > Accessibility.

## Updating the machine

After changing system or Home Manager configuration, apply it with:

```sh
./rebuild.sh
```

Files under `home/` are linked directly into the home directory. Changes to those linked files usually take effect immediately and do not require a rebuild.

## Validation

Run the same core checks used by CI without changing the active system:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.mac.system --dry-run
```

Use the configured host label instead of `mac` if it was renamed. CI also validates shell scripts and workflow files.

## Managed environment

The configuration includes:

- macOS defaults for Finder, Dock, keyboard, trackpad, appearance, and screenshots
- Homebrew applications, command-line tools, and fonts
- Zsh, Git, Starship, fzf, zoxide, and shell aliases
- Neovim with its plugin and theme configuration
- Kitty as the terminal
- AeroSpace for tiling window management
- skhd for keyboard shortcuts
- borders for active-window highlighting
- Übersicht with Simple Bar for workspaces and system status
- Zen preferences and managed browser extensions
- Shared configuration for Claude, Codex, opencode, and Herdr

Homebrew application versions follow the versions available when activation runs. Nix dependencies and source inputs are pinned by `flake.lock`.

## Keyboard shortcuts

The left Option key is the window-management modifier. The right Option key remains available for German ISO keyboard characters.

Hold Option+Escape for 250 ms to show the complete shortcut reference. Release either key to dismiss it.

| Shortcut | Action |
| --- | --- |
| left Option+Return | Open Kitty on workspace 1 |
| left Option+Shift+Return | Open Kitty running Herdr on workspace 1 |
| left Option+S | Open or focus Zen on workspace B |
| left Option+H/J/K/L | Focus a window by direction |
| left Option+Shift+H/J/K/L | Move a window by direction |
| left Option+1..4/B/C | Switch workspace |
| left Option+Shift+1..4/B/C | Move the current window to a workspace |
| left Option+Tab | Return to the previous workspace |
| left Option+F | Toggle fullscreen |
| left Option+R | Flatten the current layout |
| Control+left Option+H/J/K/L | Join with a neighboring window |
| Control+left Option+Backspace | Close every window except the current one |
| Command+E | Open Finder on workspace F |
| Command+Shift+3 | Save a region screenshot |
| Command+Shift+4 | Copy a region screenshot |
| Command+Shift+5 | Open macOS capture controls |

The authoritative shortcut definitions are in `home/.config/skhd/skhdrc`. Window rules are in `home/.config/aerospace/aerospace.toml`.

If skhd stops receiving shortcuts, restart it with:

```sh
launchctl kickstart -k gui/$UID/org.nixos.skhd
```

Run `./check-skhd.sh` to verify the service and its Accessibility permission. A changed Nix store path can require granting skhd access again after a rebuild.

## Repository layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Inputs, machine definition, and development shell |
| `flake.lock` | Pinned Nix inputs |
| `configuration.nix` | System defaults, Homebrew, services, and wallpaper activation |
| `home.nix` | Home Manager entry point |
| `modules/home/shell.nix` | Shell, Git, and prompt configuration |
| `modules/home/development.nix` | Editor, agent, and Herdr integration |
| `modules/home/desktop.nix` | Terminal, window manager, shortcuts, status bar, and launch agents |
| `modules/home/zen.nix` | Zen preferences and extension management |
| `home/` | Configuration linked into the user home directory |
| `patches/` | Checked patches for pinned upstream sources |
| `bootstrap.sh` | First installation |
| `rebuild.sh` | Subsequent system activation |
| `check-skhd.sh` | skhd health and permission check |

## Operational notes

- Simple Bar is pinned through `flake.lock` and installed into Übersicht's widget directory.
- Simple Bar settings are declared in `home/.simplebarrc` and should be changed there.
- The network widget needs Location Services access for Übersicht to display the Wi-Fi name on macOS versions that restrict network metadata.
- Neovim downloads its plugins on first launch through lazy.nvim.
- GitHub HTTPS URLs are rewritten to SSH by the Git configuration in `modules/home/shell.nix`.
- The generated Home Manager configuration manpage is disabled because its upstream derivation currently emits an invalid store-context warning.

## Support and reuse

This is a personal configuration repository. Fork it and adapt it rather than submitting feature requests or pull requests. Genuine defects can be reported through GitHub Issues.

## License

Licensed under MIT No Attribution. See `LICENSE`.
