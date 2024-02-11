{
  backupMountpoint ? "/mnt/${device}/backup",
  device,
  passwordFile ? "/dev/null",
  rootMountpoint ? "/mnt/${device}/root",
  ...
}:
import ../lib/luks_btrfs_subvolumes.nix {
  inherit device passwordFile rootMountpoint;

  name = "SanDisk_Extreme_55AE_3232";

  subvolumes = {
    "/backup" = {
      mountOptions = ["compress=zstd:9"];
      mountpoint = backupMountpoint;
    };
  };
}
