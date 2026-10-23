{ config, lib, pkgs, ... }:
let
  # Shared by both services (the upload service reads only ipp.upload.* and a couple of shared options).
  ippSettings = {
    ipp = {
      showHomePage = false;
      upload = {
        # Cloudflare (free plan) rejects request bodies over 100 MB, tunnel included.
        maxFileSize = 100;
      };
    };
  };
  ippConfigFile = (pkgs.formats.json { }).generate "ipp-config.json" ippSettings;

  uploadPort = 3001;
in
{
  # nixpkgs ships IPP 3.x (no uploads). Override with our own 4.x package, which
  # builds both the gallery proxy and the upload service.
  # TODO: drop the overlay once nixpkgs has IPP >= 4 (and ideally the upload service).
  nixpkgs.overlays = [
    (final: _prev: {
      immich-public-proxy = final.callPackage ../../../pkgs/immich-public-proxy/package.nix { };
    })
  ];

  services.immich-public-proxy = {
    enable = true;
    immichUrl = "http://127.0.0.1:2283";
    settings = ippSettings;
  };

  systemd.services.immich-public-proxy.environment.PUBLIC_BASE_URL = "https://photos.prowe.ca";

  # The nixpkgs module has no upload service, so this unit mirrors its hardening.
  systemd.services.immich-public-proxy-upload = {
    description = "Immich Public Proxy upload service (visitor uploads into shared links)";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      IMMICH_URL = config.services.immich-public-proxy.immichUrl;
      PUBLIC_BASE_URL = "https://photos.prowe.ca"; # IPP's URL, not this service's
      IPP_PORT = toString uploadPort;
      IPP_CONFIG = "${ippConfigFile}";
    };
    serviceConfig = {
      ExecStart = lib.getExe' config.services.immich-public-proxy.package "immich-public-proxy-upload";
      SyslogIdentifier = "ipp-upload";
      DynamicUser = true;
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 3;

      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateUsers = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
    };
  };

  # The tunnel can only send a hostname to one backend, so a tiny loopback-only
  # Caddy site splits photos.prowe.ca: /upload/* -> upload service, rest -> IPP.
  # Keep the /upload path intact (`handle`, not `handle_path`).
  # immich-cloudflared-tunnel.nix points photos.prowe.ca at this.
  # The address must be `http://:8088` (any Host). `http://127.0.0.1:8088` would only match
  # requests with Host: 127.0.0.1, and the tunnel forwards Host: photos.prowe.ca, so Caddy
  # answered an empty 200 for everything.
  services.caddy.virtualHosts."http://:8088" = {
    extraConfig = ''
      bind 127.0.0.1
      handle /upload/* {
        reverse_proxy 127.0.0.1:${toString uploadPort}
      }
      handle {
        reverse_proxy 127.0.0.1:${toString config.services.immich-public-proxy.port}
      }
    '';
  };
}
