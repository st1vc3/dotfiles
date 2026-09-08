# shellcheck shell=bash
#
# Resolves which flake host to build for this machine.
#
# The account names live in the private flake input, never in this repository,
# so the mapping is queried from the flake rather than hardcoded here. That
# needs a working nix, so callers must resolve the host after nix is installed
# and the inputs are fetched.

# Usage: resolve_host [requested]
#
# With an argument, validates and echoes it. Without one, asks the flake which
# host owns the current account. Echoes the host name, or fails with a message
# on stderr.
resolve_host() {
  local requested="${1:-}" account host flake="${DOTFILES_FLAKE:-$HOME/.dotfiles}"

  if [ -n "$requested" ]; then
    case "$requested" in
      personal | work)
        printf '%s' "$requested"
        return 0
        ;;
      *)
        echo "Error: unknown host '$requested' (expected: personal, work)" >&2
        return 1
        ;;
    esac
  fi

  account="$(id -un)"
  host="$(nix eval --raw "${flake}#hostForAccount.\"${account}\"" 2>/dev/null)" || host=""

  if [ -z "$host" ]; then
    echo "Error: no host configuration for account '$account'." >&2
    echo "       Add it to the hosts output of the private input, then rerun." >&2
    echo "       Or pass a host explicitly: $0 personal" >&2
    return 1
  fi

  printf '%s' "$host"
}
