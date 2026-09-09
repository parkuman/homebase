# NixOS NAS

My goal with the NAS is to have it be extremely reliable, and easily recoverable in the case something dies.
TrueNAS is great from what I can tell, but configuring most of it via UI scares me. What if it dies?!

As a result of my first little experiment making my gaming PC run NixOS, plus seeing
[NathanLaundry](https://www.youtube.com/@nathanlaundry) jump into the same NixOS NAS challenge. I thought this would be a fun experiment.

The hardware for the NAS at the time of writing is a 16GB Zimaboard2

- 500GB ssd instead of onboard emmc memory since nixos is write-heavy. would likely kill the onboard
- 6TB WD Red HDD

## Setup

- stick nixos non-gui installer on USB
  - rufus seemed to make a broken installer with errors everywhere
  - balena etcher did a great job
- boot Zimaboard2 - either DEL or ESC for bios. i mashed both
- boot into USB
- latest Linux kernel (not LTS)
- followed this guide mostly: <https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning-UEFI>
  - did not make swap partition
  - just boot and primary taking up the rest

  - ```bash
    sudo parted /dev/nvme0n1 -- mklabel gpt
    sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
    sudo parted /dev/nvme0n1 -- set 1 esp on
    sudo parted /dev/nvme0n1 -- mkpart primary 512MB 100%

    sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
    sudo mkfs.ext4 -L nixos /dev/nvme0n1p2

    sudo mount /dev/disk/by-label/nixos /mnt
    sudo mkdir -p /mnt/boot
    sudo mount /dev/disk/by-label/boot /mnt/boot

    sudo nixos-generate-config --root /mnt
    ```

### set up disko for the 6TB hard drive

- zfs not supported on linux kernel 7.x. had to pin it to `boot.kernelPackages = pkgs.linuxPackages_6_18;`
- ran into an issue where I rebuild switched with a new kernel (6.x that should support zfs), then rebooted the machine. Issue was I hadn't run disko yet so zfs tried to mount
  the tanks that weren't there, which then caused the system to not boot and ssh was lost.
  - added this to allow the system to still boot so i could then run disko

    ```nix
    fileSystems."/tank/media".options = [ "nofail" ];
    fileSystems."/tank/shared".options = [ "nofail" ];
    ```

- 6TB had no partitions and no data on it i cared about - wipe it:

```bash
nix run github:nix-community/disko/latest -- --mode disko --flake /srv/homebase/nix#nas

WARNING: This will destroy all data on the disks defined in disko.devices, which are:

  - /dev/disk/by-id/ata-WDC_WD60EFRX-68MYMN1_WD-WX21D84R1S8Y

    (If you want to skip this dialogue, pass --yes-wipe-all-disks)

Are you sure you want to wipe the devices listed above? yes
```

#### renaming zfs datasets

I wanted to rename a dataset from `shared` to `drive`. Since disko is more like a one-time setup thing, i had to run

```
sudo zfs rename data/shared data/drive
```

Then update the references in `disko.nix` (in case of a full refresh), and in `configuration.nix`.

#### Changing ownership of zfs datasets

I then ran into an issue where i couldn't make new directories via finder in the share. It was due to the fact that
disko made these shares as root. Needed to add some postcreate hook to change the ownership to the family group.

To update this declaratively (kind of) I then ran:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- --mode mount --root-mountpoint / --flake /srv/homebase/nix#nas
```

### adding new users

- created a family group, then added users
- for each new user, add them to `configuration.nix`
- then rebuild switch
- `passwd <name>`

### samba

- added smb shares into `configuration.nix`
- `systemctl status samba-smbd` to check how its doin
- `sudo smbpasswd -a <user>` to set samba (different from unix) password
