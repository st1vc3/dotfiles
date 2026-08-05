{ lib, pkgs, firefox-addons, ... }:

let
  zenAddons = firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  zenExtensions = pkgs.symlinkJoin {
    name = "zen-extensions";
    paths = [ zenAddons.ublock-origin zenAddons.sponsorblock ];
  };
  zenExtensionManifest = pkgs.runCommand "zen-extension-manifest" { } ''
    find "${zenExtensions}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}" \
      -mindepth 1 -maxdepth 1 -exec basename {} \; | sort > $out
  '';
  zenUserJs = pkgs.writeText "zen-user.js" ''
    user_pref("extensions.autoDisableScopes", 0);
    user_pref("browser.warnOnQuit", false);
    user_pref("browser.warnOnQuitShortcut", false);
    user_pref("browser.sessionstore.warnOnQuit", false);
    user_pref("browser.tabs.warnOnClose", false);
    user_pref("browser.tabs.warnOnCloseOtherTabs", false);
  '';
in
{
  home.activation.zenExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profilesIni="$HOME/Library/Application Support/zen/profiles.ini"
    if [ -f "$profilesIni" ]; then
      zenProfile="$(${pkgs.gawk}/bin/awk '
        /^\[Install/ { inInstall=1; next }
        /^\[/ { inInstall=0 }
        inInstall && /^Default=/ { sub(/^Default=/, ""); print; exit }
      ' "$profilesIni")"
      if [ -n "$zenProfile" ]; then
        profileDir="$HOME/Library/Application Support/zen/$zenProfile"
        extensionsDir="$profileDir/extensions"
        managedExtensions="$profileDir/.nix-managed-extensions"
        $DRY_RUN_CMD mkdir -p "$profileDir"
        if [ -L "$extensionsDir" ]; then
          $DRY_RUN_CMD rm "$extensionsDir"
        fi
        $DRY_RUN_CMD mkdir -p "$extensionsDir"
        if [ -f "$managedExtensions" ]; then
          while IFS= read -r extensionId; do
            if ! grep -Fxq "$extensionId" "${zenExtensionManifest}"; then
              extensionPath="$extensionsDir/$extensionId"
              if [ -L "$extensionPath" ]; then
                $DRY_RUN_CMD rm "$extensionPath"
              fi
            fi
          done < "$managedExtensions"
        fi
        for extension in "${zenExtensions}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"/*; do
          $DRY_RUN_CMD ln -sfn "$extension" "$extensionsDir/$(basename "$extension")"
        done
        $DRY_RUN_CMD ln -sfn "${zenUserJs}" "$profileDir/user.js"
        manifestTmp="$managedExtensions.tmp"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0644 "${zenExtensionManifest}" "$manifestTmp"
        $DRY_RUN_CMD ${pkgs.coreutils}/bin/mv -f "$manifestTmp" "$managedExtensions"
      fi
    fi
  '';
}
