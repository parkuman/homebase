{ pkgs, lib, ... }:
let
  dadQnap = (import ../../../lib/hosts.nix).dadQnap;

  /* build a bash script as a package */
  healthcheck = pkgs.writeShellApplication {
    name = "nas-healthchecks";
    runtimeInputs = [ pkgs.systemd pkgs.curl pkgs.util-linux pkgs.zfs pkgs.tailscale pkgs.gnugrep pkgs.iputils ];
    text = /* bash */ ''
      fail=0
      check() {
        local label=$1; shift
        if "$@" >/dev/null 2>&1; then
          echo "OK   $label"
        else
          echo "FAIL $label"; fail=1
        fi
      }

      check "sshd active" systemctl is-active --quiet sshd

      # tailscale: daemon up and logged in (status exits non-zero if stopped/logged out)
      check "tailscaled active" systemctl is-active --quiet tailscaled
      check "tailscale connected" tailscale status

      # QNAP (restic rest server) reachable over tailscale
      check "qnap reachable" curl -s --max-time 5 -o /dev/null http://${dadQnap}:8000/

      # zfs: "zpool status -x" exits 0 even when unhealthy, so grep its output
      # shellcheck disable=SC2329  # called indirectly via check()
      zfs_healthy() { [ "$(zpool status -x)" = "all pools are healthy" ]; }
      check "zfs pools healthy" zfs_healthy

      # immich: service active and API answering locally
      check "immich-server active" systemctl is-active --quiet immich-server
      check "immich api ping" curl -sf --max-time 5 http://127.0.0.1:2283/api/server/ping

      exit $fail
    '';
  };
in
{
  environment.systemPackages = [ healthcheck ];

  systemd.services.nas-healthcheck = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe healthcheck;
    };
  };

}
