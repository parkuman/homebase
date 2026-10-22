{ ... }:
{
  # TODO: uploads
  # Uploads need IPP 4.x plus the separate immich-public-proxy-upload 
  # container. nixpkgs ships IPP 3.4.0, which has no upload button, 
  # and there's no packaged upload service.

  services.immich-public-proxy = {
    enable = true;
    immichUrl = "http://127.0.0.1:2283";
    settings.ipp.showHomePage = false;
  };

  systemd.services.immich-public-proxy.environment.PUBLIC_BASE_URL = "https://photos.prowe.ca";
}
