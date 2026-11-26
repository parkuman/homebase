{
  description = "Parker's Nix Setup";

  inputs = {
    # shorthand for github.com/NixOS/nixpkgs...
    # nixpkgs.url = "nixpkgs/nixos-25.11";
    nixpkgs.url = "nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      # url = "github:nix-community/home-manager/release-25.11";
      url = "github:nix-community/home-manager/master";
      # prevents home-manager from pulling its own version of nixpkgs, avoiding mismatched package sets
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # TEMP: nixpkgs PR #593266 (immich-public-proxy 4.2.0) for testing; remove once merged
    nixpkgs-ipp.url = "github:r-ryantm/nixpkgs/4c8674ef854039e4d6cdc80fbe11db2b1b0f7914";
    # `stable` branch tracks the latest release
    pi = {
      url = "github:earendil-works/pi/stable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      home-manager,
      nix-darwin,
      ragenix,
      pi,
      nixpkgs-ipp,
      ...
    }:
    let
      user = import ./lib/user.nix;
    in
    {
      darwinConfigurations = {
        parker-m3 = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit user; };
          modules = [
            ./hosts/macos/parker-m3/configuration.nix
          ];
        };
        cci-m4 = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit user; };
          modules = [
            ./hosts/macos/cci-m4/configuration.nix
          ];
        };
      };
      nixosConfigurations = {
        nas = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit user; };
          modules = [
            ./hosts/nixos/nas/configuration.nix
            ./hosts/nixos/nas/disko.nix
            disko.nixosModules.disko
            ragenix.nixosModules.default
            # TEMP: use immich-public-proxy from nixpkgs PR #593266. Listed last so this
            # overlay wins over the local one in modules/services/immich-public-proxy.
            (
              { ... }:
              {
                nixpkgs.overlays = [
                  (_final: prev: {
                    immich-public-proxy =
                      nixpkgs-ipp.legacyPackages.${prev.stdenv.hostPlatform.system}.immich-public-proxy;
                  })
                ];
              }
            )
          ];
        };
        parker-desktop = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit user; };
          modules = [
            ./hosts/nixos/parker-desktop/configuration.nix
            # we include home-manager as a module here becase we want home-manager
            # to be managed by the flake itself (i.e. we don't have to bootstrap it
            # separately, everything is applied with a nixos-rebuild switch)
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                backupFileExtension = "backup";
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit user pi; };
                users.${user.username} = {
                  imports = [ ./hosts/nixos/parker-desktop/home.nix ];
                };
              };
            }
          ];
        };
      };
    };
}
