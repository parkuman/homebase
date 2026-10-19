let
  qnapHost = "100.127.86.79";
  qnapUser = "nasty-pee";
in
{ config, pkgs, ... }:
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # on all NixOS machines
  age.secrets.restic-password.file = ./secrets/restic-password.age;
  age.secrets.restic-qnap-rest-container-htpasswd.file = ./secrets/restic-qnap-rest-container-htpasswd.age;

  services.restic.backups.dad = {
    initialize = true;
    repository = "rest:http://${qnapHost}:8000/nas/";
    passwordFile = config.age.secrets.restic-password.path;
    environmentFile = config.age.secrets.restic-qnap-rest-container-htpasswd.path;
    paths = [ "/tank/drive" ];
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true; # runs a missed backup after downtime
      RandomizedDelaySec = "10m"; # jitter
    };
  };

  systemd.services.restic-backups-dad = {
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
  };
}
