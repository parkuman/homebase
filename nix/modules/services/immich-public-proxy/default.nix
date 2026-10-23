# Local stand-in for the IPP 4.x + upload support that is waiting to land in nixpkgs.
#   package.nix -> pkgs/by-name/im/immich-public-proxy/package.nix
#   module.nix  -> nixos/modules/services/web-apps/immich-public-proxy.nix
# Delete this directory once nixpkgs has caught up.
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
