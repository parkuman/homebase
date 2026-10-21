{ pkgs, ... }:
{
  services.immich = {
    enable = true;
    mediaLocation = "/tank/photos";
    host = "0.0.0.0";
    openFirewall = true;
    machine-learning.enable = true;
  };
}
