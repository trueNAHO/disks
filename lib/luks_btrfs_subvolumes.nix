{
  device,
  name,
  passwordFile ? "/dev/null",
  rootMountpoint ? "/mnt/${device}",
  subvolumes ? {},
}: {
  disko.devices.disk.${name} = {
    inherit device;

    content = {
      partitions.luks = {
        content = {
          inherit name passwordFile;

          content = {
            extraArgs = ["-f"];

            subvolumes =
              {
                "/root" = {
                  mountOptions = ["compress=zstd"];
                  mountpoint = rootMountpoint;
                };
              }
              // subvolumes;

            type = "btrfs";
          };

          settings.allowDiscards = true;
          type = "luks";
        };

        size = "100%";
      };

      type = "gpt";
    };

    type = "disk";
  };
}
