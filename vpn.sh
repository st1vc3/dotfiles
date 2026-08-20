#!/usr/bin/env bash
set -euo pipefail

# CLI GlobalProtect client, built on openconnect.
#
# Palo Alto only ships a GUI client for macOS, so this drives openconnect,
# which speaks the same GlobalProtect protocol. openconnect needs root to
# create the utun device and install routes, hence the sudo calls.
#
# The portal and account live in .env, which is not tracked. Copy .env.example
# to .env and fill it in.

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
ENV_FILE="$(dirname "$SELF")/.env"
PID_FILE="/var/run/openconnect-globalprotect.pid"
IFACE_FILE="/var/run/openconnect-globalprotect.iface"
VPNC_SCRIPT="/opt/homebrew/etc/vpnc/vpnc-script"

# A value already in the environment beats .env, so a single run can override
# the checked-out configuration.
env_portal="${VPN_PORTAL:-}"
env_user="${VPN_USER:-}"
if [ -r "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090 # path is derived at runtime, not checkable here
  . "$ENV_FILE"
  set +a
fi
if [ -n "$env_portal" ]; then
  VPN_PORTAL="$env_portal"
fi
if [ -n "$env_user" ]; then
  VPN_USER="$env_user"
fi
VPN_PORTAL="${VPN_PORTAL:-}"
VPN_USER="${VPN_USER:-}"

usage() {
  cat <<'EOF'
Usage: vpn [command]

Commands:
  up          Connect to the VPN (default when no command is given)
  down        Disconnect
  status      Report whether the tunnel is up, with interface and address
  logs        Follow the openconnect log

Configuration lives in .env next to this script:
  VPN_PORTAL  Portal hostname
  VPN_USER    Account to authenticate as

Either can be overridden for a single run by setting it in the environment.
EOF
}

die() {
  echo "vpn: $*" >&2
  exit 1
}

require_config() {
  [ -n "$VPN_PORTAL" ] ||
    die "VPN_PORTAL is not set - copy .env.example to .env and fill it in"
  [ -n "$VPN_USER" ] ||
    die "VPN_USER is not set - copy .env.example to .env and fill it in"
}

# Echoes the pid of a live openconnect, or fails if the tunnel is down.
tunnel_pid() {
  local pid
  [ -r "$PID_FILE" ] || return 1
  pid="$(cat "$PID_FILE" 2>/dev/null)" || return 1
  [ -n "$pid" ] || return 1
  # openconnect runs as root, so kill -0 from the invoking user fails with
  # EPERM even while the process is alive. ps reports across owners.
  ps -p "$pid" -o pid= >/dev/null 2>&1 || return 1
  printf '%s' "$pid"
}

# openconnect runs this in place of vpnc-script. It is the only point where
# the tunnel device name is known, so record it for `status` and then hand
# off to the real vpnc-script with the environment untouched.
#
# This deliberately reads no configuration: it has to keep working for a
# tunnel started before .env changed, or teardown would strand the very routes
# it exists to remove.
cmd_hook() {
  # Recording the interface is a convenience for `status`; never let it fail
  # the run, or a read-only /var/run would take the whole tunnel down with it.
  case "${reason:-}" in
    connect) printf '%s\n' "${TUNDEV:-}" >"$IFACE_FILE" || true ;;
    disconnect) rm -f "$IFACE_FILE" || true ;;
  esac
  exec "$VPNC_SCRIPT"
}

cmd_up() {
  local waited
  local -a args

  require_config
  command -v openconnect >/dev/null 2>&1 ||
    die "openconnect is not installed - run 'rebuild' to install it"
  [ -x "$VPNC_SCRIPT" ] ||
    die "vpnc-script missing at $VPNC_SCRIPT - reinstall the openconnect formula"

  if tunnel_pid >/dev/null; then
    cmd_status
    return 0
  fi

  echo "==> Connecting to $VPN_PORTAL as $VPN_USER"

  # Prime sudo first so its prompt cannot collide with openconnect's.
  sudo -v

  args=(
    --protocol=gp
    --user="$VPN_USER"
    --os=mac-intel
    --script="$SELF _hook"
    --background
    --pid-file="$PID_FILE"
    --syslog
    --reconnect-timeout=60
    "$VPN_PORTAL"
  )

  # Leave stdin on the terminal so openconnect can prompt for the password and
  # then the MFA challenge at the moment each is needed. Queueing the answers
  # through a pipe fails twice over: a time-based passcode collected up front
  # can expire during portal authentication, which the gateway rejects with an
  # HTTP 512, and any re-prompt after that hits EOF.
  sudo openconnect "${args[@]}"

  waited=0
  while [ "$waited" -lt 15 ]; do
    if tunnel_pid >/dev/null; then
      cmd_status
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  die "openconnect exited before the tunnel came up - see 'vpn logs'"
}

cmd_down() {
  local pid waited
  if ! pid="$(tunnel_pid)"; then
    echo "Not connected"
    sudo rm -f "$PID_FILE" "$IFACE_FILE"
    return 0
  fi

  echo "==> Disconnecting from ${VPN_PORTAL:-the VPN}"
  # SIGINT makes openconnect log out of the session and let vpnc-script tear
  # down the routes; SIGKILL would leave both behind.
  sudo kill -INT "$pid"

  waited=0
  while tunnel_pid >/dev/null && [ "$waited" -lt 10 ]; do
    sleep 1
    waited=$((waited + 1))
  done

  if tunnel_pid >/dev/null; then
    echo "vpn: clean disconnect timed out, terminating" >&2
    sudo kill -TERM "$pid" 2>/dev/null || true
  fi

  sudo rm -f "$PID_FILE" "$IFACE_FILE"
  echo "Disconnected"
}

cmd_status() {
  local pid iface addr
  if ! pid="$(tunnel_pid)"; then
    echo "Disconnected"
    return 1
  fi

  iface="$(cat "$IFACE_FILE" 2>/dev/null || true)"
  if [ -n "$iface" ]; then
    addr="$(ifconfig "$iface" 2>/dev/null | awk '/inet /{ print $2; exit }')"
    echo "Connected to ${VPN_PORTAL:-the VPN} (pid $pid, $iface${addr:+, $addr})"
  else
    echo "Connected to ${VPN_PORTAL:-the VPN} (pid $pid)"
  fi
}

cmd_logs() {
  exec log stream --style compact --level info --predicate 'process == "openconnect"'
}

main() {
  local cmd="${1:-up}"
  if [ "$#" -gt 0 ]; then
    shift
  fi

  case "$cmd" in
    up | connect) cmd_up ;;
    down | disconnect) cmd_down ;;
    status) cmd_status ;;
    logs) cmd_logs ;;
    _hook) cmd_hook ;;
    help | -h | --help) usage ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
