{
  config,
  lib,
  pkgs,
  user,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../../modules/shared/unfree.nix
    ../../../modules/services/sabnzbd
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "parker-desktop-nixos";

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  time.timeZone = "America/Toronto";

  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  services.pulseaudio.enable = false;
  # hands out realtime scheduling priority to user processes on demand, used by Pipewire to prioritise audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  services.tailscale.enable = true;

  # Publish the loopback-bound T3 Code server (modules/apps/t3code) over
  # Tailscale HTTPS, so tailnet devices reach it at
  #   https://parker-desktop-nixos.<tailnet>.ts.net/
  # Remote clients pair once with a code from `t3 pair`. No firewall holes
  # needed: Tailscale Serve terminates TLS and forwards to 127.0.0.1:3773.
  systemd.services.tailscale-serve-t3code = {
    description = "Publish T3 Code over Tailscale Serve (HTTPS)";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # tailscaled may not be logged in yet at boot, and Tailscale Serve must
      # be enabled once for the tailnet (Tailscale prints the enable URL).
      # Bound each attempt so a not-yet-enabled Serve doesn't hang the unit;
      # after enabling Serve, run: systemctl restart tailscale-serve-t3code
      attempt=0
      while [ "$attempt" -lt 20 ]; do
        if ${pkgs.coreutils}/bin/timeout 30 \
          ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://127.0.0.1:3773; then
          exit 0
        fi
        attempt=$((attempt + 1))
        sleep 5
      done
      echo "timed out configuring Tailscale Serve for T3 Code" >&2
      exit 1
    '';
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth = {
    enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${user.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
    # Keep the user systemd manager (and its services, e.g. t3code) running at
    # boot, without requiring an interactive login.
    linger = true;
  };

  programs.zsh.enable = true;
  programs.firefox.enable = true;

  # to get tree-sitter working inside nvim, we do the non-nix way
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    tree-sitter
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "amdgpu.dc=1"
    "amdgpu.dpm=1"
  ];

  unfreePackages = [
    "claude-code"
    "discord"
    "obsidian"
    "proton-pass-cli"
    "steam"
    "steam-unwrapped"
  ];

  environment.systemPackages =
    with pkgs;
    [
      ghostty
    ]
    ++ (import ../../../modules/shared/packages.nix { inherit pkgs; });

  # fonts.packages = with pkgs; [
  #       nerd-fronts.jetbrains-mono
  # ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # DO NOT CHANGE. Installed April 2nd 2026
  system.stateVersion = "25.11";

}
