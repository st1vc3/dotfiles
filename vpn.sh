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

# Where DNS goes back to whenever the tunnel is not up. Deliberately a constant
# rather than a .env value: teardown runs as root and must never read .env, and
# a resolver that differed between that path and the CLI would be worse than no
# fallback at all.
FALLBACK_DNS="1.1.1.1"

VPN_PORTAL="${VPN_PORTAL:-}"
VPN_USER="${VPN_USER:-}"

# Reads the portal and account from .env. A value already in the environment
# beats .env, so a single run can override the checked-out configuration.
#
# This is called per command rather than at file scope, and deliberately NOT on
# the _hook path: openconnect runs the hook as root, and .env is writable by
# the invoking user, so sourcing it there would execute user-writable shell
# with root privileges.
load_config() {
  local env_portal="${VPN_PORTAL:-}"
  local env_user="${VPN_USER:-}"

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
}

usage() {
  cat <<EOF
Usage: vpn [command]

Commands:
  up          Connect to the VPN (default when no command is given)
  down        Disconnect and put DNS back on $FALLBACK_DNS
  status      Report whether the tunnel is up, with interface and address
  logs        Follow the openconnect log

Whenever the tunnel goes down - on request, on a reconnect timeout, or because
openconnect died - DNS is set back to $FALLBACK_DNS and the resolver cache is
flushed.

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

# openconnect runs the tunnel script as root; the user-facing commands have to
# ask for privileges themselves.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Names every enabled network service that currently holds an address. Writing
# DNS to the inactive ones would work too, but it would also rewrite the
# configuration of networks this machine simply is not on.
active_network_services() {
  local service
  while IFS= read -r service; do
    case "$service" in
      # The listing header, the '*' that marks a disabled service, blank lines.
      An\ asterisk* | '*'* | '') continue ;;
    esac
    networksetup -getinfo "$service" 2>/dev/null |
      grep -q '^IP address: [0-9]' || continue
    printf '%s\n' "$service"
  done < <(networksetup -listallnetworkservices 2>/dev/null || true)
}

# Points DNS back at the fallback resolver and drops the cache.
#
# On connect, vpnc-script writes the gateway's servers onto the active network
# service with `networksetup -setdnsservers`; on disconnect it sets that service
# back to `Empty`. So even a clean teardown lands on whatever DHCP hands out
# rather than the resolver this machine wants - and a teardown that never runs,
# after a reconnect timeout or a crash or a SIGKILL, leaves the gateway's
# unreachable servers configured and every lookup failing.
restore_dns() {
  local service
  while IFS= read -r service; do
    as_root networksetup -setdnsservers "$service" "$FALLBACK_DNS" || true
  done < <(active_network_services)

  # Flush whether or not anything was rewritten: names resolved through the
  # tunnel outlive it, and split-horizon answers are wrong off the VPN.
  as_root dscacheutil -flushcache || true
  as_root killall -HUP mDNSResponder 2>/dev/null || true
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
# This reads no configuration, by design. It runs as root, and it has to keep
# working for a tunnel started before .env changed, or teardown would strand
# the very routes it exists to remove.
cmd_hook() {
  local status

  # Recording the interface is a convenience for `status`; never let it fail
  # the run, or a read-only /var/run would take the whole tunnel down with it.
  case "${reason:-}" in
    connect) printf '%s\n' "${TUNDEV:-}" >"$IFACE_FILE" || true ;;
    disconnect)
      rm -f "$IFACE_FILE" || true
      # Let vpnc-script tear the tunnel down first: it rewrites the active
      # service's DNS itself, so anything set before it ran would simply be
      # overwritten. The fallback goes on top of whatever it leaves behind.
      status=0
      "$VPNC_SCRIPT" || status=$?
      restore_dns
      return "$status"
      ;;
  esac
  exec "$VPNC_SCRIPT"
}

cmd_up() {
  local waited
  local -a args

  require_config
  command -v openconnect >/dev/null 2>&1 ||
    die "openconnect is not installed - it is declared for the work host in hosts/work.nix"
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

  # openconnect got far enough to fork but the tunnel never appeared, and it
  # may have rewritten DNS on the way. Put the fallback back before giving up.
  restore_dns
  die "openconnect exited before the tunnel came up - see 'vpn logs'"
}

cmd_down() {
  local pid waited
  if ! pid="$(tunnel_pid)"; then
    echo "Not connected"
    sudo rm -f "$PID_FILE" "$IFACE_FILE"
    # Reached after openconnect died on its own, which is exactly the case
    # where DNS is left stranded on the gateway's servers.
    restore_dns
    echo "DNS reset to $FALLBACK_DNS"
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
  # The teardown hook has already done this; repeat it in case openconnect died
  # before the hook could run, or had to be terminated outright above.
  restore_dns
  echo "Disconnected, DNS reset to $FALLBACK_DNS"
}

cmd_status() {
  local pid iface addr
  if ! pid="$(tunnel_pid)"; then
    if [ -e "$PID_FILE" ]; then
      # openconnect exited without tearing anything down, so DNS may still
      # point at the gateway. `down` is what clears both.
      echo "Disconnected (openconnect exited without cleaning up - run 'vpn down')"
    else
      echo "Disconnected"
    fi
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
    up | connect)
      load_config
      cmd_up
      ;;
    down | disconnect)
      load_config
      cmd_down
      ;;
    status)
      load_config
      cmd_status
      ;;
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
