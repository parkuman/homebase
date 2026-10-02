{ ... }:
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; # on all NixOS machines
  age.secrets.restic-password.file = ./secrets/restic-password.age;
}
