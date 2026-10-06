# Lets any module declare the unfree packages it needs via `unfreePackages`;
# the lists are merged into a single allowUnfreePredicate.
{ config, lib, ... }:

{
  options.unfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Names of unfree packages to allow.";
  };

  config.nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.unfreePackages;
}
