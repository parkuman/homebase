{ config, ... }:
{
  # TODO: remove once this lands in nixpkgs
  imports = [ ../../../modules/services/immich-public-proxy ];

  services.immich-public-proxy = {
    enable = true;
    immichUrl = "http://127.0.0.1:2283";
    publicBaseUrl = "https://photos.prowe.ca";

    # enable user uploads
    upload.enable = true;
    settings.ipp = {
      showHomePage = false;
      upload = {
        # Cloudflare (free plan) rejects request bodies over 100 MB, tunnel included.
        maxFileSize = 100;
        # TODO: upload notifications
        # notifyUrl = "https://ntfy.sh/your-random-topic?tpl=yes&t={{.title}}&m={{.message}}";
      };
    };
  };

  # The tunnel can only send a hostname to one backend, so a loopback-only Caddy site
  # splits photos.prowe.ca: /upload/* -> upload service, everything else -> IPP.
  # immich-cloudflared-tunnel.nix points photos.prowe.ca here.
  #
  # The address must be `http://:8088` (any Host). `http://127.0.0.1:8088` would only match
  # Host: 127.0.0.1, and the tunnel forwards Host: photos.prowe.ca, so Caddy would answer an
  # empty 200 for everything. `handle` (not `handle_path`) keeps the /upload prefix, which
  # the upload service expects.
  services.caddy.virtualHosts."http://:8088".extraConfig = ''
    bind 127.0.0.1
    handle /upload/* {
      reverse_proxy 127.0.0.1:${toString config.services.immich-public-proxy.upload.port}
    }
    handle {
      reverse_proxy 127.0.0.1:${toString config.services.immich-public-proxy.port}
    }
  '';
}
