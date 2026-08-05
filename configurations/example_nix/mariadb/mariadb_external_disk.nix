{ pkgs, ... }:

{
  # Mount the external disk that will hold the MariaDB data directory.
  # Use /dev/disk/by-uuid/... (stable across reboots) instead of /dev/sdX.
  # Find the UUID with `lsblk -f`. Filesystem must support unix permissions
  # (ext4/btrfs/xfs) — not exfat/ntfs.
  fileSystems."/srv/mariadb" = {
    device = "/dev/disk/by-uuid/change_it_to_the_disk_uuid_using_lsblk";
    fsType = "ext4";
    # If the disk is unplugged, boot continues normally instead of waiting/
    # dropping to emergency mode. mysql.service still won't start without it
    # (see the requires/after below).
    options = [ "nofail" ];
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;

    # Data directory lives on the external disk mounted above, instead of
    # the default /var/lib/mysql on the system disk/SD card.
    dataDir = "/srv/mariadb/mysql";

    # Local access only: no port is opened, clients on this machine connect
    # through the unix socket at /run/mysqld/mysqld.sock.
    settings.mysqld = {
      # 0.0.0.0 (Everyone)
      # 127.0.0.1 (Localhost Only)
      bind-address = "0.0.0.0";
    };

    ensureDatabases = [ "database_name_change_it_ok" ];

    # After the service is up, create the user manually:
    # sudo mysql -e "CREATE USER 'username'@'%' IDENTIFIED BY 'strong_password'; GRANT ALL PRIVILEGES ON database_name_change_it_ok.* TO 'username'@'%'; FLUSH PRIVILEGES;"
  };

  # Create the dataDir on the external disk before MariaDB starts. Required
  # because mysql.service's own sandboxing (mount namespacing) fails with
  # "No such file or directory" if this path doesn't exist yet - which is
  # always true on a freshly mounted/empty disk. "d" creates it if missing
  # and fixes ownership/mode on every boot; harmless once it already exists.
  systemd.tmpfiles.rules = [
    "d /srv/mariadb/mysql 0700 mysql mysql - -"
  ];

  # Make sure the external disk is mounted, and the dataDir created above,
  # before MariaDB starts. Otherwise it may fail to start (empty mount point)
  # or initialize a fresh database directly on it. Unit name is the mount
  # path with "/" turned into "-" (systemd-escape).
  systemd.services.mysql = {
    after = [ "srv-mariadb.mount" "systemd-tmpfiles-setup.service" ];
    requires = [ "srv-mariadb.mount" ];
  };
}
