# Pi coding agent, from the pi flake input (github:earendil-works/pi/stable).
# Requires `pi` in home-manager extraSpecialArgs.
{ pkgs, pi, ... }:

{
  home.packages = [ pi.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
