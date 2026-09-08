_:

{
  # `package` is left at its default of null so the system client stays in
  # use. Apple's ssh is the one that understands UseKeychain.
  programs.ssh = {
    enable = true;

    # The module's built-in defaults are being retired upstream and warn on
    # every rebuild, so every value this config depends on is spelled out.
    enableDefaultConfig = false;

    settings."*" = {
      AddKeysToAgent = "yes";
      UseKeychain = true;
      IdentitiesOnly = true;
      ServerAliveInterval = 60;

      # Remote hosts almost never carry terminfo for xterm-kitty, which makes
      # clear, tput and less fail with "unknown terminal type" over SSH.
      # Announce a terminal type every host ships in ncurses instead.
      SetEnv.TERM = "xterm-256color";
    };
  };
}
