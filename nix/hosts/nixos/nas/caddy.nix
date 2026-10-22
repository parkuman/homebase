{ pkgs, ... }:
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "photos.home.prowe.ca" = {
        useACMEHost = "home.prowe.ca";
        extraConfig = ''
          reverse_proxy 127.0.0.1:2283
        '';
      };

      ":443" = {
        useACMEHost = "home.prowe.ca";
        extraConfig = ''
          respond 404
        '';
      };

      ":80" = {
        extraConfig = ''
          redir https://{host}{uri} permanent
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
