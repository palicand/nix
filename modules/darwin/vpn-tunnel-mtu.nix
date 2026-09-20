{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.networking.vpnTunnelMtu;
in
{
  options.networking.vpnTunnelMtu = {
    enable = mkEnableOption "capping the MTU of active NordLayer tunnel interfaces";

    limit = mkOption {
      type = types.ints.positive;
      default = 1380;
      description = ''
        Largest MTU allowed on a NordLayer tunnel interface, in bytes.

        Some uplinks carry IPv4 inside IPv6 and so offer a path MTU below the
        usual 1500; one link in regular use here tops out at 1460. A
        WireGuard-derived VPN adds 60 bytes of its own and sets the tunnel to
        1420 by default, which puts full-size packets past that ceiling. They
        are then discarded in silence. The tunnel still establishes, because
        handshakes are small, but bulk transfers stall and long-lived sessions
        die once real payload starts moving, which reads as a flaky link
        rather than a packet size problem.

        1380 is the largest value measured to survive that uplink. 1400 did
        not, so the usable ceiling sits below what the arithmetic alone
        suggests and this should not be cut fine.
      '';
    };

    interval = mkOption {
      type = types.ints.positive;
      default = 1;
      description = ''
        Seconds between checks.

        NordLayer can reapply its own MTU while connected and exposes no
        setting for it on macOS, so the value has to be reasserted quickly.
        launchd offers no trigger for this, hence polling.
      '';
    };
  };

  config = mkIf cfg.enable {
    launchd.daemons.vpn-tunnel-mtu = {
      script = ''
        /sbin/ifconfig | /usr/bin/awk '
          /^[a-z]/ {
            iface = ""
            if ($0 ~ /^utun/) {
              iface = substr($1, 1, length($1) - 1)
              mtu = $NF
            }
          }
          /^\tinet / {
            if (iface != "") {
              print iface, mtu
              iface = ""
            }
          }
        ' | while read -r iface mtu; do
          if [ "$mtu" -gt ${toString cfg.limit} ]; then
            /sbin/ifconfig "$iface" mtu ${toString cfg.limit}
            echo "$(/bin/date '+%F %T') capped $iface from $mtu to ${toString cfg.limit}"
          fi
        done
      '';

      serviceConfig = {
        RunAtLoad = true;
        StartInterval = cfg.interval;
        ThrottleInterval = cfg.interval;
        StandardOutPath = "/var/log/vpn-tunnel-mtu.log";
        StandardErrorPath = "/var/log/vpn-tunnel-mtu.log";
      };
    };
  };
}
