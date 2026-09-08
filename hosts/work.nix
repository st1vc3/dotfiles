# Work machine. Corporate tooling that has no place on the personal machine.
_:

{
  # The corporate portal speaks GlobalProtect, which Palo Alto only ships a
  # GUI client for. vpn.sh drives openconnect against it instead.
  homebrew.brews = [
    "openconnect"
  ];

  homebrew.casks = [
    "microsoft-teams"
    "webex"
    "signal"
  ];
}
