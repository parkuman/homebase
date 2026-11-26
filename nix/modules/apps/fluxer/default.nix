# Fluxer: open source chat/VoIP client, built from source (see package.nix).
{ pkgs, ... }:

{
  home.packages = [ (pkgs.callPackage ./package.nix { }) ];
}
