# This is a script for you as example for a automatic process
# that starts with the system and automatically restarts at 00:00

{ ... }:

{
  # Get the UUID using: ls -la /dev/disk/by-uuid/
  fileSystems."/home/generic-user/generic-server" = {
    device = "/dev/disk/by-uuid/change_it_to_the_disk_uuid_using_lsblk";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  systemd.tmpfiles.rules = [
    "d /home/generic-user/generic-server 0755 generic-user users -"
  ];

  # Make sure the external disk is mounted, and the directory above created,
  # before the server starts. Otherwise it may start on an empty mount point
  # or write its data directly to the system disk. Unit name is the mount
  # path with "/" turned into "-" and existing "-" escaped as "\x2d"
  # (systemd-escape --path "/home/generic-user/generic-server").
  systemd.services.generic-server = {
    description = "Generic Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "home-generic\\x2duser-generic\\x2dserver.mount" "systemd-tmpfiles-setup.service" ];
    requires = [ "home-generic\\x2duser-generic\\x2dserver.mount" ];

    serviceConfig = {
      User = "generic-user";
      WorkingDirectory = "/home/generic-user/generic-server";
      ExecStart = "/home/generic-user/generic-server/start.sh";
      Restart = "on-failure";
      RestartSec = "10s";
      # Expose all system packages — systemd services don't inherit the user PATH.
      Environment = "PATH=/run/current-system/sw/bin:/run/wrappers/bin";
    };
  };

  # Restart on 00:00
  systemd.timers.generic-server-daily-restart = {
    description = "Restart generic server daily at midnight";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.generic-server-daily-restart = {
    description = "Restart generic server";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/run/current-system/sw/bin/systemctl restart generic-server.service";
    };
  };
}
