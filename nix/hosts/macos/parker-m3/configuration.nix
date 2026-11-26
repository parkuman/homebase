{
  pkgs,
  ...
}:
{
  imports = [ ../../../modules/darwin ];
  system.stateVersion = 5;
  environment.systemPackages = [
    (pkgs.callPackage ../../../modules/apps/fluxer/package-darwin.nix { })
  ];
}
