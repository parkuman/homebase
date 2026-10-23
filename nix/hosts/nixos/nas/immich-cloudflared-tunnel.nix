{ config, ... }:
{
  age.secrets.cloudflared-tunnel-immich.file = ./secrets/cloudflared-tunnel-immich.age;

  services.cloudflared = {
    enable = true;
    tunnels = {
      "e0d89431-8c18-41fa-8912-122ef431494b" = {
        credentialsFile = config.age.secrets.cloudflared-tunnel-immich.path;
        default = "http_status:404";
        ingress = {
          # Caddy splits /upload/* (upload service) from everything else (IPP); see immich-public-proxy.nix
          "photos.prowe.ca" = "http://127.0.0.1:8088";
        };
      };
    };
  };
}
