let
  qnapHost = "100.127.86.79";
  qnapUser = "nasty-pee";
  qnapPath = "/backup/nas";
  keyFile = "/var/lib/restic-dad/id_ed25519";
in
{ config, pkgs, ... }:
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # on all NixOS machines
  age.secrets.restic-password.file = ./secrets/restic-password.age;

  systemd.services.restic-dad-ssh-key = {
    wantedBy = [ "multi-user.target" ];
    before = ["restic-backups-dad.service"];
    unitConfig.ConditionPathExists = "!${keyFile}";
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "restic-dad"; # dir where keyFile reads
      StateDirectoryMode = "0700"; # User / owner can read, can write and can execute.
      ExecStart = "${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N '' -C restic@nas -f ${keyFile}";
    };
  };

  programs.ssh.knownHosts.dad-qnap = {
    hostNames = [ qnapHost ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+ZxkE27vDmhwWZFIDqZ/7vgKxGhrnfzdLK0b5Qnwuz"; # ssh-keyscan -t ed25519 <host ip>
  };

  services.restic.backups.dad = {
    initialize = true;
    repository = "sftp:${qnapUser}@${qnapHost}:${qnapPath}";
    passwordFile = config.age.secrets.restic-password.path;
    paths = [ "/tank/drive" ];
    extraOptions = [
      "sftp.args='-i ${keyFile} -o BatchMode=yes -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes'" # -i is the key, BatchMode means never prompt, StrictHostKeyChecking=yes means refuse unknown hosts, IdentitiesOnly means only use that key.
    ];
    timerConfig = {
      OnCalendar = "02:30";
      Persistent = true; # runs a missed backup after downtime
      RandomizedDelaySec = "10m"; # jitter
    };
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12" ];
  };

  systemd.services.restic-backups-dad = {
    requires = [ "restic-dad-ssh-key.service" ];
    after = [ "restic-dad-ssh-key.service" "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
  };
}
