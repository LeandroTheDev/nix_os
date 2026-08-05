{ config, lib, pkgs, ... }:
{
  # Don't forget to add the group "docker" to the user you want to use docker

  # Mount the external disk that will hold Docker's data-root.
  # Use /dev/disk/by-uuid/... (stable across reboots) instead of /dev/sdX.
  # Find the UUID with `lsblk -f`.
  fileSystems."/var/lib/docker" = {
    device = "/dev/disk/by-uuid/change_it_to_the_disk_uuid_using_lsblk";
    fsType = "ext4";
    # If the disk is unplugged, boot continues normally instead of waiting/
    # dropping to emergency mode. docker.service still won't start without it
    # (see the requires/after below).
    options = [ "nofail" ];
  };

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      data-root = "/var/lib/docker";
    };
  };

  # Make sure the external disk is mounted before Docker starts. Otherwise it
  # may fail to start (empty mount point) or initialize data-root directly on
  # the system disk. Unit name is the mount path with "/" turned into "-"
  # (systemd-escape).
  systemd.services.docker = {
    after = [ "var-lib-docker.mount" ];
    requires = [ "var-lib-docker.mount" ];
  };
}
