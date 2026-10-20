let
  qnapHost = "100.127.86.79";
in
{ config, pkgs, ... }:
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # on all NixOS machines
  age.secrets.restic-password.file = ./secrets/restic-password.age;
  age.secrets.restic-qnap-rest-container.file = ./secrets/restic-qnap-rest-container.age;

  services.restic.backups.dad = {
    initialize = true;
    repository = "rest:http://${qnapHost}:8000/nas/";
    passwordFile = config.age.secrets.restic-password.path;
    environmentFile = config.age.secrets.restic-qnap-rest-container.path;
    paths = [ "/tank/drive" ];
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true; # runs a missed backup after downtime
      RandomizedDelaySec = "10m"; # jitter
    };
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12" ];
  };

  systemd.services.restic-backups-dad = {
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
  };
}
