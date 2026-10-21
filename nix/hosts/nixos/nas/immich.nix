{ pkgs, ... }:
{
  services.immich = {
    enable = true;
    mediaLocation = "/tank/photos";
    host = "0.0.0.0";
    openFirewall = true;
    machine-learning.enable = true;
  };

  # The nixpkgs module expects mediaLocation to already exist and be writable
  # by the immich user, and it won't set that up for us. data/photos is a
  # separate ZFS dataset, so its mountpoint is owned by root until we say otherwise.
  #
  # "d" = create the directory if missing, and also enforce mode/owner/group on
  # it if it already exists. Fields: type path mode user group age argument.
  # 0750: immich can read/write, its group can read, everyone else is locked out.
  # Photos are only ever accessed via Immich, not directly (e.g. over Samba).
  systemd.tmpfiles.rules = [
    "d /tank/photos 0750 immich immich - -"
  ];

  # Safety guard: refuse to start Immich unless /tank/photos is a real mount.
  # The fstab entry has "nofail", so if data/photos ever fails to mount, boot
  # carries on and /tank/photos is just an empty directory on the SSD root.
  # Without this, Immich would start anyway and quietly write every upload to
  # the SSD instead of the ZFS pool (and those photos would then be hidden
  # underneath the dataset the next time it mounts).
  # RequiresMountsFor makes systemd pull in the mount unit and fail the start
  # if it isn't mounted. Both services get it since they both use the dataset.
  systemd.services.immich-server.unitConfig.RequiresMountsFor = "/tank/photos";
  systemd.services.immich-machine-learning.unitConfig.RequiresMountsFor = "/tank/photos";
}
