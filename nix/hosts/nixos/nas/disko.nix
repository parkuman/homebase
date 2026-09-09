{
  disko.devices = {
    disk = {
      hdd1 = {
        device = "/dev/disk/by-id/ata-WDC_WD60EFRX-68MYMN1_WD-WX21D84R1S8Y";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "data";
              };
            };
          };
        };
      };
    };

    zpool = {
      data = {
        type = "zpool";
        options = {
          # 2^12 = 4096K sector alignment
          ashift = "12";
        };
        rootFsOptions = {
          compression = "lz4";
          atime = "off";
        };

        datasets = {
          # movies,tv,music
          media = {
            type = "zfs_fs";
            mountpoint = "/tank/media";
            options = {
              mountpoint = "legacy";
              recordsize = "1M"; # large sequential files
            };
          };

          # file backups and such
          drive = {
            type = "zfs_fs";
            mountpoint = "/tank/drive";
            options = {
              mountpoint = "legacy";
            };
          };
        };
      };
    };
  };
}
