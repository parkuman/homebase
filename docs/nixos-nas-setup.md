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
