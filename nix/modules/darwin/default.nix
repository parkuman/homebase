{ pkgs, user, ... }:
{
  environment.systemPackages =
    with pkgs;
    [ /* any shared darwin specific packages i may want */ ]
    ++ (import ../shared/packages.nix { inherit pkgs; });

  nix = {
    package = pkgs.nix;

    settings = {
      trusted-users = [
        "@admin"
        "${user.username}"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
    };

    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  system = {
    # Turn off NIX_PATH warnings now that we're using flakes
    checks.verifyNixPath = false;
    primaryUser = user.username;

    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 15;
      };

      dock = {
        autohide = true;
        show-recents = false;
        launchanim = true;
        orientation = "left";
        tilesize = 48;
        showMissionControlGestureEnabled = true;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = false; # this overrides the three fingers up for mission control. Disable it.
        TrackpadThreeFingerVertSwipeGesture = 2;
      };
    };
  };
}
