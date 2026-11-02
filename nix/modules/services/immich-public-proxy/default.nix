# Local stand-in for the `publicBaseUrl` option, which is waiting to land in nixpkgs.
# Copies of the nixpkgs branch (the 4.x package and upload service are already in nixpkgs):
#   package.nix -> pkgs/by-name/im/immich-public-proxy/package.nix
#   module.nix  -> nixos/modules/services/web-apps/immich-public-proxy.nix
# Delete this directory once nixpkgs has caught up (package.nix can go as soon as the flake's
# nixpkgs input has 4.1.2).
{ ... }:
{
  disabledModules = [ "services/web-apps/immich-public-proxy.nix" ];
  imports = [ ./module.nix ];

  nixpkgs.overlays = [
    (final: _prev: {
      immich-public-proxy = final.callPackage ./package.nix { };
    })
  ];
}
