{ config, lib, pkgs, simpleBar, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  simpleBarWithNetworkAddress = pkgs.runCommand "simple-bar-with-network-address" { } ''
    cp -R ${simpleBar} $out
    chmod -R u+w $out
    patch --directory=$out --strip=1 --fuzz=0 < ${../../patches/simple-bar-network-address.patch}
  '';
  reloadUbersicht = pkgs.writeShellScript "reload-uebersicht" ''
    /usr/bin/pkill -TERM -f '/Applications/.*bersicht.app/Contents/' || true
    attempt=0
    while /usr/bin/pgrep -f '/Applications/.*bersicht.app/Contents/' >/dev/null && [ "$attempt" -lt 10 ]; do
      /bin/sleep 1
      attempt=$((attempt + 1))
    done

    /usr/bin/open -g -b tracesOf.Uebersicht
    attempt=0
    until /usr/bin/osascript -e 'tell application id "tracesOf.Uebersicht" to refresh widget id "simple-bar-index-jsx"' >/dev/null 2>&1; do
      attempt=$((attempt + 1))
      if [ "$attempt" -ge 15 ]; then
        echo "warning: Übersicht started but Simple Bar was not ready after 15 seconds" >&2
        break
      fi
      /bin/sleep 1
    done
  '';
in
{
  home.file.".config/kitty".source = liveLink "home/.config/kitty";

  home.file.".config/aerospace".source = liveLink "home/.config/aerospace";

  # Same class of bug as skhd below: aerospace.toml is an out-of-store symlink,
  # and auto-reload-config tracks it by inode, which git/home-manager rewrite
  # on every checkout or rebuild. Without this, AeroSpace can run for weeks on
  # a stale ruleset (window-placement rules silently stop firing) until it's
  # quit and relaunched by hand.
  home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if /usr/bin/pgrep -x AeroSpace >/dev/null 2>&1; then
      if ! $DRY_RUN_CMD /opt/homebrew/bin/aerospace reload-config; then
        echo "warning: AeroSpace config reload failed" >&2
      fi
    fi
  '';

  home.file.".config/skhd".source = liveLink "home/.config/skhd";

  # skhd runs as a nix-darwin launchd agent, but its config is an out-of-store
  # symlink edited live in the repo. skhd's config watcher tracks the file by
  # inode, which git rewrites on checkout, so the daemon can silently keep
  # running a stale config after a rebuild or pull. Kick the service on every
  # activation so the current skhdrc is always loaded. The Accessibility grant
  # is tied to skhd's /nix/store path and survives a same-path restart.
  home.activation.reloadSkhd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/Library/LaunchAgents/org.nixos.skhd.plist" ]; then
      if ! $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$(id -u)/org.nixos.skhd"; then
        echo "warning: skhd reload failed" >&2
      fi
    fi
  '';

  # screencapture (bound in skhd to cmd+shift+3/4) writes here; create it up
  # front so a fresh machine doesn't silently fail on the first screenshot.
  home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/Pictures/screenshots"
  '';

  home.file.".simplebarrc".source = ../../home/.simplebarrc;

  home.file."Library/Application Support/Übersicht/widgets/simple-bar".source = simpleBarWithNetworkAddress;

  # Hide Übersicht's welcome widget while keeping Simple Bar visible.
  home.file."Library/Application Support/tracesOf.Uebersicht/WidgetSettings.json".text =
    builtins.toJSON {
      "GettingStarted-jsx" = {
        hidden = true;
        screens = [ ];
        showOnAllScreens = true;
        showOnMainScreen = false;
        showOnSelectedScreens = false;
      };
      "simple-bar-index-jsx" = {
        hidden = false;
        screens = [ ];
        showOnAllScreens = true;
        showOnMainScreen = false;
        showOnSelectedScreens = false;
      };
    };

  # Reload Übersicht on rebuild so managed settings reach its long-lived WebView.
  home.activation.reloadUbersicht = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${reloadUbersicht}
  '';

  # Start Übersicht once per login, then refresh Simple Bar after its external
  # configuration has loaded. Übersicht remains running after the shell exits.
  launchd.agents.uebersicht = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/usr/bin/open -g /Applications/Übersicht.app; /bin/sleep 2; /usr/bin/osascript -e 'tell application id \"tracesOf.Uebersicht\" to refresh widget id \"simple-bar-index-jsx\"'"
      ];
      RunAtLoad = true;
    };
  };
  # Keep the active-window border independent from AeroSpace restarts.
  launchd.agents.borders = {
    enable = true;
    config = {
      ProgramArguments = [
        "/opt/homebrew/bin/borders"
        "active_color=0xffff4057"
        "inactive_color=0x00000000"
        "width=3.0"
        "style=round"
        "hidpi=on"
      ];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
}
