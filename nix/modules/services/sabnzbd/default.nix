{ ... }:

{
  imports = [ ../../shared/unfree.nix ];

  services.sabnzbd.enable = true;

  # unrar is needed for extracting RAR archives
  unfreePackages = [ "unrar" ];
}
