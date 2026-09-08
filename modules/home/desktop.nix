{
  config,
  lib,
  pkgs,
  simpleBar,
  private,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  # Ubersicht's page is fully transparent, so backdrop-filter has no backdrop to
  # sample and renders non-deterministically. Bake a blurred copy of the
  # wallpaper instead and let the bar composite it. Heavy blur is all low
  # frequency, so a small downscaled JPEG upscales cleanly and stays tiny.
  wallpaperBlur =
    pkgs.runCommand "simple-bar-wallpaper-blur.jpg" { nativeBuildInputs = [ pkgs.imagemagick ]; }
      ''
        magick ${private}/abstract/red.jpg -resize 900x -blur 0x18 -quality 82 $out
      '';
  simpleBarWithNetworkAddress = pkgs.runCommand "simple-bar-with-network-address" { } ''
    cp -R ${simpleBar} $out
    chmod -R u+w $out
    patch --directory=$out --strip=1 --fuzz=0 < ${../../patches/simple-bar-network-address.patch}
    cp ${wallpaperBlur} $out/wallpaper-blur.jpg
  '';
  uebersichtWidgetSettings = pkgs.writeText "uebersicht-widget-settings.json" (
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
    }
  );
  ubersichtProcess = "/Applications/.*bersicht.app/Contents/";
  # Starts Übersicht and waits until Simple Bar actually answers, rather than
  # sleeping a fixed interval and hoping. Both the login agent and the
  # rebuild-time reload go through this, so they wait identically.
  startUbersicht = pkgs.writeShellScript "start-uebersicht" ''
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
  # Activation has to restart Übersicht so the widget picks up its new store
  # path; login only needs the start half above.
  reloadUbersicht = pkgs.writeShellScript "reload-uebersicht" ''
    /usr/bin/pkill -TERM -f '${ubersichtProcess}' || true
    attempt=0
    while /usr/bin/pgrep -f '${ubersichtProcess}' >/dev/null && [ "$attempt" -lt 10 ]; do
      /bin/sleep 1
      attempt=$((attempt + 1))
    done

    exec ${startUbersicht}
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

  home.file.".hammerspoon".source = liveLink "home/.hammerspoon";

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

  home.file."Library/Application Support/Übersicht/widgets/simple-bar".source =
    simpleBarWithNetworkAddress;

  # Ubersicht rewrites WidgetSettings.json at runtime, so it cannot be a
  # read-only store symlink: the app silently fails to persist widget state and
  # stops placing widgets on any screen. Seed it as a plain writable file
  # instead - declarative on every rebuild, mutable in between.
  home.activation.uebersichtWidgetSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settingsDir="$HOME/Library/Application Support/tracesOf.Uebersicht"
    $DRY_RUN_CMD mkdir -p "$settingsDir"
    $DRY_RUN_CMD rm -f "$settingsDir/WidgetSettings.json"
    $DRY_RUN_CMD install -m 0644 ${uebersichtWidgetSettings} "$settingsDir/WidgetSettings.json"
  '';

  home.activation.reloadUbersicht = lib.hm.dag.entryAfter [ "uebersichtWidgetSettings" ] ''
    $DRY_RUN_CMD ${reloadUbersicht}
  '';

  launchd.agents.uebersicht = {
    enable = true;
    config = {
      ProgramArguments = [ "${startUbersicht}" ];
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
  launchd.agents.hammerspoon = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/open"
        "-g"
        "-a"
        "Hammerspoon"
      ];
      RunAtLoad = true;
    };
  };
}
