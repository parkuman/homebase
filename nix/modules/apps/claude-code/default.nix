# Claude Code: Anthropic's agentic coding CLI (`claude`).
#
# Claude Code is unfree. It is installed here via home.packages, which uses the
# global NixOS `pkgs` (home-manager.useGlobalPkgs = true), so its license is
# allowed by the host's `unfreePackages` list in
# hosts/nixos/parker-desktop/configuration.nix (see modules/shared/unfree.nix).
# A home-manager module cannot declare that itself: setting `nixpkgs.config`
# here would be ignored and warns to that effect.
{ pkgs, ... }:

{
  home.packages = [ pkgs.claude-code ];
}
