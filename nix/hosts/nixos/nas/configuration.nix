# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, user, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest LTS kernel since ZFS is known to support.
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  
  # Add ZFS support.
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false; # nix suggests this is explicitly set to false

  networking.hostName = "nas";
  networking.hostId = "3f1b15aa"; # required by ZFS. is just a random 8 char string. without this, "ZFS requires networking.hostId to be set" will be raised

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  time.timeZone = "America/Toronto";

  # if these zfs pools don't exist, don't block boot
  fileSystems."/tank/media".options = [ "nofail" ];
  fileSystems."/tank/shared".options = [ "nofail" ];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # ZFS services
  services.zfs.autoSnapshot.enable = true;
  services.zfs.autoScrub.enable = true; # Regular scrubbing of ZFS pools is recommended. Defaults to once a week: https://wiki.nixos.org/wiki/ZFS

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.groups.family = {};

  users.users.${user.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "family" ];
  };

  users.users.jill = {
    isNormalUser = true;
    extraGroups = [ "family" ];
  };

  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     tree
  #   ];
  # };

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  services.samba = {
    enable = true;
    openFirewall = true; # opens 139/445 tcp + 137/138 udp automatically
    settings = {
      # reference that is helpful: https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html
      global = {
        security = "user"; # auth against local unix accounts
      };
      media = {
        path = "/tank/media";
        browseable = "yes"; # when someone connects to \\nas\ (Windows) or smb://nas/ (Mac Finder) and looks at the list of available folders, this share shows up in that list
        "valid users" = "@family";
        "force group" = "family";
        "guest ok" = "no";
        "read only" = "no";
        "create mask" = "0664";      # cap new files at rw-rw-r--, no execute bit needed for data
        "directory mask" = "2775";   # rwxrwxr-x + setgid so new subfolders inherit the family group
      };
    };
  };


  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "26.05"; # Did you read the comment?

}
