# Work machine shell tooling. Imported from home.nix only for the work host,
# so none of this reaches the personal machine.
{ lib, ... }:

{
  # vpn.sh drives openconnect against the corporate GlobalProtect portal. The
  # openconnect brew it needs is declared in hosts/work.nix.
  programs.zsh.shellAliases.vpn = "$HOME/.dotfiles/vpn.sh";

  # Ordered after the shared block in shell.nix, which is mkOrder 1500.
  programs.zsh.initContent = lib.mkOrder 1550 ''
    # jwp - jenkins work pull. Refreshes every repo in the jenkins-git
    # workspace, then drops you in the jenkins-setup root. It is a function
    # rather than an alias to a script because a script runs in a subshell and
    # cannot change the directory of the shell that called it.
    export JENKINS_WORK_ROOT="$HOME/Documents/cargo-partner/jenkins-git"
    jwp() {
      "$HOME/.dotfiles/jenkins-work-pull.sh" "$@"
      local rc=$?
      cd "$JENKINS_WORK_ROOT/jenkins-setup" 2>/dev/null || {
        print -u2 "jwp: could not cd to $JENKINS_WORK_ROOT/jenkins-setup"
        return 1
      }
      print -P "%B-> $PWD%b"
      return $rc
    }
  '';
}
