{ config, pkgs, lib, ... }:
let
  cfg = config.nas.healthchecks;
  checks = lib.attrsToList cfg; # [{ name; value = { script; path; }; }]

  # each check becomes a bash function (exit status = result), run via check()
  checkFns = lib.imap0 (i: c: ''
    check_${toString i}() {
      ${c.value.script}
    }
    check ${lib.escapeShellArg c.name} check_${toString i}
  '') checks;

  /* build a bash script as a package */
  healthcheck = pkgs.writeShellApplication {
    name = "nas-healthchecks";
    runtimeInputs = lib.unique (lib.concatMap (c: c.value.path) checks);
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

      ${lib.concatStrings checkFns}

      exit $fail
    '';
  };

  # runs the checks and reports to healthchecks.io: <url>/<exit code> (0 = up,
  # non-zero = down), with the OK/FAIL output as the ping body so it shows in
  # the healthchecks.io event log. If pings stop arriving (NAS down), the
  # healthchecks.io grace period expires and it alerts too.
  pinger = pkgs.writeShellApplication {
    name = "nas-healthchecks-ping";
    runtimeInputs = [ pkgs.curl ];
    text = /* bash */ ''
      rc=0
      out=$(${lib.getExe healthcheck} 2>&1) || rc=$?
      echo "$out"
      curl -fsS -m 10 --retry 3 -o /dev/null --data-raw "$out" \
        "$(cat ${config.age.secrets.healthchecks-nas-health-url.path})/$rc"
      exit "$rc"
    '';
  };
in
{
  options.nas.healthchecks = lib.mkOption {
    default = { };
    description = ''
      Health checks run by nas-healthchecks. Each module declares its own, so
      un-importing a module removes its checks too. Name = label shown in output.
    '';
    example = lib.literalExpression ''
      { "foo api" = { path = [ pkgs.curl ]; script = "curl -sf http://127.0.0.1:1234/"; }; }
    '';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        script = lib.mkOption {
          type = lib.types.lines;
          description = "Bash snippet. Exit status 0 = healthy.";
        };
        path = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Packages the script needs on PATH.";
        };
      };
    });
  };

  config = {
    # checks that aren't owned by any other module
    nas.healthchecks = {
      "sshd active" = { path = [ pkgs.systemd ]; script = "systemctl is-active --quiet sshd"; };

      # tailscale: daemon up and logged in (status exits non-zero if stopped/logged out)
      "tailscaled active" = { path = [ pkgs.systemd ]; script = "systemctl is-active --quiet tailscaled"; };
      "tailscale connected" = { path = [ pkgs.tailscale ]; script = "tailscale status"; };

      # zfs: "zpool status -x" exits 0 even when unhealthy, so grep its output
      "zfs pools healthy" = {
        path = [ pkgs.zfs ];
        script = ''[ "$(zpool status -x)" = "all pools are healthy" ]'';
      };
    };

    environment.systemPackages = [ healthcheck ];

    age.secrets.healthchecks-nas-health-url.file = ./secrets/healthchecks-nas-health-url.age;

    systemd.services.nas-healthcheck = {
      after = [ "network-online.target" "tailscaled.service" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe pinger;
      };
    };

    systemd.timers.nas-healthcheck = {
      wantedBy = [ "timers.target" ];
      # OnCalendar rather than OnUnitActiveSec: the latter stops rescheduling if
      # a run is skipped via ExecCondition (see backup.nix)
      timerConfig.OnCalendar = "*:0/5"; # every 5 min
    };
  };
}
