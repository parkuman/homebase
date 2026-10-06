# Pi coding agent, from the pi flake input (github:earendil-works/pi/stable).
# Requires `pi` in home-manager extraSpecialArgs.
{
  config,
  pkgs,
  pi,
  ...
}:

let
  dotfiles_pi = "${config.home.homeDirectory}/homebase/dotfiles/.pi/agent";
  # only link tracked config; ~/.pi/agent also holds runtime state (auth, sessions)
  tracked = [
    "settings.json"
    "extensions"
    "themes"
  ];
in

{
  home.packages = [ pi.packages.${pkgs.stdenv.hostPlatform.system}.default ];

  home.file = builtins.listToAttrs (
    map (name: {
      name = ".pi/agent/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${dotfiles_pi}/${name}";
    }) tracked
  );
}
