{ pkgs, ... }:
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "http://photos.home.prowe.ca" = {
        extraConfig = ''
          reverse_proxy 127.0.0.1:2283
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
