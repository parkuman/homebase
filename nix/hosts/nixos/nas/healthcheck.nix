{ pkgs, ... }:
let
  /* build a bash script as a package */
  healthcheck = pkgs.writeShellApplication {
    name = "nas-healthchecks";
    runtimeInputs = [ pkgs.systemd pkgs.curl pkgs.util-linux pkgs.zfs ];
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

      exit $fail
    '';
  };
in
{
  environment.systemPackages = [ healthcheck ];

  systemd.services.nas-healthcheck = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${healthcheck}/bin/nas-healthcheck"; 
    };
  };

}
