{ lib, pkgs, ... }:
let
  homeLAN = "192.168.40.0/24";
  tailscale = "100.64.0.0/10";
  tailscaleIPv6 = "fd7a:115c:a1e0::/48";
  allowedRanges = [ homeLAN tailscale tailscaleIPv6 ];

  # function that denies anything not in LAN / Tailnet.
  privateSite = upstream: {
    useACMEHost = "home.prowe.ca";
    extraConfig = ''
      @denied not remote_ip ${lib.concatStringsSep " " allowedRanges}
      respond @denied 403
      reverse_proxy ${upstream}
    '';
  };
in
{
  services.caddy = {
    enable = true;
    virtualHosts = {
      "photos.home.prowe.ca" = privateSite "127.0.0.1:2283";

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
