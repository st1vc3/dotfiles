# macosx

Declarative Apple Silicon macOS configuration built with nix-darwin, Home Manager, and Homebrew.

This repository manages system defaults, applications, command-line tools, shell configuration, development tools, browser settings, and a keyboard-driven desktop environment. It is a personal setup covering two machines.

## Requirements

- An Apple Silicon Mac
- Administrator access
- Internet access
- Xcode Command Line Tools
- `gh` authenticated against the account that owns `dotfiles-private`

The private input is fetched over https using `gh`'s git credential helper, so run `gh auth login` before the first build. No SSH key is required.

## Hosts

The flake defines one configuration per machine:

| Host | Extra system module | Extra Home Manager module |
| --- | --- | --- |
| `personal` | `hosts/personal.nix` | - |
| `work` | `hosts/work.nix` | `modules/home/work.nix` |

Everything both machines share lives in `hosts/common.nix`. A host module adds only what must not reach the other machine - `hosts/work.nix` adds Microsoft Teams, Webex, Signal, and openconnect.

The same split applies to the user environment. `home.nix` imports `modules/home/work.nix` only for the work host, which is where corporate-only shell tooling lives: the `vpn` alias and the `jwp` Jenkins workspace helper. Neither is defined on the personal machine.

The macOS account each host builds for comes from the private `dotfiles-private` flake input, so no account name appears in this repository. Evaluation still stays pure, because a flake input is fetched like any other dependency; only the input's URL and revision are recorded in `flake.lock`.

`bootstrap.sh` and `rebuild.sh` ask the flake which host owns the current account, so neither takes an argument in normal use. Pass one to override:

```sh
./rebuild.sh work
```

Adding a machine means adding an entry to `hosts` in `flake.nix`, a matching entry in the private input, and the host label to the case in `host.sh`.

Homebrew activation uses `cleanup = "zap"`. Every formula and cask that should remain installed must be declared for that host. Anything undeclared is removed during activation, so a package declared only in `hosts/work.nix` is actively uninstalled from the personal machine.

## Fresh installation

Clone the repository:

```sh
git clone git@github.com:st1vc3/macosx.git
cd macosx
```

If macOS prompts to install the Command Line Tools, complete that installation before continuing. Then run:

```sh
./bootstrap.sh
```

The bootstrap process installs Nix when needed, links the repository at `~/.dotfiles`, creates `.env`, fetches the flake inputs, applies the system configuration, initializes Zen extensions, starts AeroSpace, and verifies skhd.

### Local configuration

`.env` is not tracked, so machine-specific hosts and accounts stay out of the repository. Copy `.env.example` to `.env` and fill it in; `bootstrap.sh` creates it for you.

| Variable | Used by |
| --- | --- |
| `HERDR_REMOTE` | SSH target for the `rcc` remote Herdr session |
| `VPN_PORTAL` | GlobalProtect portal hostname for `vpn.sh` |
| `VPN_USER` | Account `vpn.sh` authenticates as |

None of these are needed to build the system. The macOS account is not among them - it belongs to the host definition in `flake.nix`.

macOS may request Accessibility access for AeroSpace, skhd, and Hammerspoon. Grant it under System Settings > Privacy & Security > Accessibility.

## Updating the machine

After changing system or Home Manager configuration, apply it with:

```sh
./rebuild.sh
```

Files under `home/` are linked directly into the home directory. Changes to those linked files usually take effect immediately and do not require a rebuild.

## Validation

Run the same checks CI runs, without changing the active system:

```sh
nix flake check --no-build
nix build .#darwinConfigurations.personal.system --dry-run
nix build .#darwinConfigurations.work.system --dry-run
```

The linters live in the `ci` development shell:

```sh
nix develop .#ci --command nixfmt --check $(git ls-files '*.nix')
nix develop .#ci --command statix check .
nix develop .#ci --command deadnix --fail $(git ls-files '*.nix')
nix develop .#ci --command stylua --check $(git ls-files '*.lua')
nix develop .#ci --command luacheck $(git ls-files '*.lua')
nix develop .#ci --command shellcheck -x bootstrap.sh rebuild.sh check-skhd.sh vpn.sh host.sh jenkins-work-pull.sh
```

Nix files are formatted with `nixfmt` and Lua with `stylua`; both are enforced, so run them without `--check` to fix. `statix`'s `repeated_keys` rule is disabled in `statix.toml` because it conflicts with the dotted-option style nix-darwin and Home Manager use.

CI runs the linters, the Neovim plugin check, and the repository invariants on a Linux runner, and only the darwin system build on macOS, because macOS runner minutes bill at ten times the Linux rate.

## Managed environment

The configuration includes:

- macOS defaults for Finder, Dock, keyboard, trackpad, and appearance
- Touch ID for `sudo`
- Homebrew applications, command-line tools, and fonts
- Zsh, Git, Starship, fzf, zoxide, and shell aliases
- Neovim with its plugin, theme, and language server configuration
- Kitty as the terminal
- AeroSpace for tiling window management
- skhd for keyboard shortcuts, including the screenshot bindings
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
| Command+Shift+3 | Save a region screenshot to `~/Pictures/screenshots` |
| Command+Shift+4 | Copy a region screenshot to the clipboard |
| Command+Shift+5 | Open macOS capture controls |

Command+Shift+3 and Command+Shift+4 are skhd bindings that replace the macOS defaults, so both capture a region rather than the full screen.

The authoritative shortcut definitions are in `home/.config/skhd/skhdrc`. Window rules are in `home/.config/aerospace/aerospace.toml`.

If skhd stops receiving shortcuts, restart it with:

```sh
launchctl kickstart -k gui/$UID/org.nixos.skhd
```

Run `./check-skhd.sh` to verify the service and its Accessibility permission. It only restarts skhd when the service is actually down. A changed Nix store path can require granting skhd access again after a rebuild.

## VPN

Work host only. The corporate portal speaks GlobalProtect, which Palo Alto only
ships a GUI client for. `vpn.sh` drives `openconnect` instead and is aliased to
`vpn`:

| Command | Effect |
| --- | --- |
| `vpn` | Connect |
| `vpn status` | Show the tunnel interface and assigned address |
| `vpn down` | Disconnect, tear down the routes, and reset DNS |
| `vpn logs` | Follow the openconnect log |

Set `VPN_PORTAL` and `VPN_USER` in `.env` (see [Local
configuration](#local-configuration)), so the portal and account stay out of
the repository. Either value can be overridden for a single run from the
environment.

Connecting needs `sudo`, since openconnect creates the tunnel device and
installs routes. The gateway requires a second factor, so openconnect prompts
for the password and then an MFA passcode on every connection.

`vpn.sh` re-invokes itself as openconnect's tunnel script, which openconnect
runs as root. That path deliberately reads no configuration, so a user-writable
`.env` is never executed with root privileges.

Connecting installs the gateway's DNS servers on whichever network service is
active. A tunnel that ends badly - a reconnect timeout, a crash, a `kill -9` -
leaves every lookup pointing at servers that are no longer reachable, and even a
clean teardown only falls back to whatever DHCP hands out. So whenever the
tunnel goes down, `vpn.sh` sets DNS to `1.1.1.1` and flushes the resolver cache.
That runs on the teardown path and again on `vpn down`, which means `vpn down`
also repairs DNS after openconnect has already died on its own.

## Repository layout

| Path | Purpose |
| --- | --- |
| `flake.nix` | Inputs, host definitions, and development shell |
| `flake.lock` | Pinned Nix inputs |
| `hosts/common.nix` | System defaults, Homebrew, services, and wallpaper activation |
| `hosts/personal.nix` | Personal machine additions |
| `hosts/work.nix` | Work machine additions |
| `home.nix` | Home Manager entry point |
| `modules/home/shell.nix` | Shell, Git, and prompt configuration |
| `modules/home/development.nix` | Editor, language servers, agent, and Herdr integration |
| `modules/home/desktop.nix` | Terminal, window manager, shortcuts, status bar, and launch agents |
| `modules/home/ssh.nix` | SSH client configuration |
| `modules/home/work.nix` | Work-only shell tooling (`vpn`, `jwp`) |
| `modules/home/zen.nix` | Zen preferences and extension management |
| `home/` | Configuration linked into the user home directory |
| `patches/` | Checked patches for pinned upstream sources |
| `host.sh` | Account to host mapping, sourced by the scripts |
| `bootstrap.sh` | First installation |
| `rebuild.sh` | Subsequent system activation |
| `check-skhd.sh` | skhd health and permission check |
| `vpn.sh` | GlobalProtect VPN client over openconnect (work host only) |
| `jenkins-work-pull.sh` | Jenkins workspace refresh behind `jwp` (work host only) |
| `statix.toml`, `.stylua.toml`, `.luacheckrc` | Linter configuration |

## Operational notes

- Simple Bar is pinned through `flake.lock` and installed into Übersicht's widget directory.
- Simple Bar settings are declared in `home/.simplebarrc` and should be changed there.
- The network widget needs Location Services access for Übersicht to display the Wi-Fi name on macOS versions that restrict network metadata.
- Neovim downloads its plugins on first launch through lazy.nvim.
- Neovim uses its built-in LSP client, configured in `home/.config/nvim/lua/lsp.lua`. Servers are declared in `modules/home/development.nix` and resolved from `PATH`; anything not installed is skipped. Adding a language means adding the server package there and an entry in `lsp.lua`.
- Git rewrites GitHub HTTPS URLs to SSH for pushes only (`pushInsteadOf`). Fetches and clones stay on HTTPS, which is what lets tooling bootstrap itself from GitHub without a key loaded, and what lets Nix fetch the private input through `gh`'s credential helper. Rewriting fetches as well would break both.
- The private input carries wallpapers and account names. Nothing fetched by a flake input is a secret: inputs land in `/nix/store`, which is world-readable on the machine that fetched them. Real credentials must never go there.
- The generated Home Manager configuration manpage is disabled because its upstream derivation currently emits an invalid store-context warning.

## Support and reuse

This is a private personal configuration repository. It is not intended for reuse, and it carries machine-specific account names.

## License

Licensed under MIT No Attribution. See `LICENSE`.
