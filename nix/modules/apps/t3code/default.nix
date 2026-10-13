# T3 Code: control surface for coding agents (Claude Code, Codex, OpenCode,
# Pi, ...). Installs the pinned nightly CLI/server as `t3` and runs it as a
# systemd user service on loopback.
#
# Why loopback: T3 picks its auth policy from the bind host. Binding anything
# other than 127.0.0.1 (e.g. 0.0.0.0) makes the server "remote-reachable",
# which changes the session-cookie name and requires a one-time pairing token
# for *every* browser, including localhost. Keeping it on loopback keeps local
# access trusted and no-code.
#
# Remote access is provided by Tailscale Serve instead: a root systemd unit in
# hosts/nixos/parker-desktop/configuration.nix publishes this loopback port at
#     https://parker-desktop-nixos.<tailnet>.ts.net/
# Remote clients pair once with a code from `t3 pair` (or `t3 pair --label x`).
#
# Requires `pi` (and any other provider CLI) to be installed and authenticated
# on this machine — see modules/apps/pi. Provider CLIs are resolved from the
# home-manager profile, which is on the service's PATH.
#
# Note: do NOT run `t3 service install` on this host. Nix owns the unit
# (t3code.service); `t3 update` likewise bypasses Nix. Bump `version` in
# package.nix instead.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  t3code = pkgs.callPackage ./package.nix { };

  # Keep in sync with the Tailscale Serve unit in
  # hosts/nixos/parker-desktop/configuration.nix.
  port = 3773;
  host = "127.0.0.1";

  extraArgs = [ ];
in

{
  home.packages = [ t3code ];

  systemd.user.services.t3code = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "T3 Code agent control surface";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };

    Service = {
      ExecStart = lib.concatStringsSep " " (
        [
          "${t3code}/bin/t3"
          "serve"
          "--host"
          host
          "--port"
          (toString port)
        ]
        ++ extraArgs
      );
      WorkingDirectory = config.home.homeDirectory;
      Restart = "on-failure";
      RestartSec = 5;
      # Give provider CLIs (pi, codex, claude, git, ...) the same PATH they
      # have in an interactive shell: the home profile plus the system profile.
      Environment = [
        "PATH=${lib.makeBinPath [ config.home.profileDirectory ]}:/run/current-system/sw/bin"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };
}
