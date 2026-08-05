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

  home.activation.reloadAerospace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if /usr/bin/pgrep -x AeroSpace >/dev/null 2>&1; then
      if ! $DRY_RUN_CMD /opt/homebrew/bin/aerospace reload-config; then
        echo "warning: AeroSpace config reload failed" >&2
      fi
    fi
  '';

  home.file.".config/skhd".source = liveLink "home/.config/skhd";

  home.activation.reloadSkhd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -f "$HOME/Library/LaunchAgents/org.nixos.skhd.plist" ]; then
      if ! $DRY_RUN_CMD /bin/launchctl kickstart -k "gui/$(id -u)/org.nixos.skhd"; then
        echo "warning: skhd reload failed" >&2
      fi
    fi
  '';

  home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/Pictures/screenshots"
  '';

  home.file.".simplebarrc".source = ../../home/.simplebarrc;

  home.file."Library/Application Support/Übersicht/widgets/simple-bar".source = simpleBarWithNetworkAddress;

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

  home.activation.reloadUbersicht = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${reloadUbersicht}
  '';

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
