# Example systemd service for a Docker-based server with graceful shutdown
# and data stored on an external disk.
# When the service stops or restarts (including the daily midnight restart),
# systemd runs ExecStop first, which gives Docker time to shut the container
# down gracefully before killing anything.

{ ... }:

{
  # Get the UUID using: ls -la /dev/disk/by-uuid/
  fileSystems."/home/generic-user/generic-server-data" = {
    device = "/dev/disk/by-uuid/change_it_to_the_disk_uuid_using_lsblk";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  systemd.tmpfiles.rules = [
    "d /home/generic-user/generic-server-data 0755 generic-user users -"
  ];

  # Make sure the external disk is mounted, and the directory above created,
  # before the container starts. Otherwise Docker may bind-mount an empty
  # directory and the server writes its data to a temporary layer that is lost
  # on restart. Unit name is the mount path with "/" turned into "-" and
  # existing "-" escaped as "\x2d"
  # (systemd-escape --path "/home/generic-user/generic-server-data").
  systemd.services.generic-server = {
    description = "Generic Docker Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network.target" "home-generic\\x2duser-generic\\x2dserver\\x2ddata.mount" "systemd-tmpfiles-setup.service" ];
    requires = [ "docker.service" "home-generic\\x2duser-generic\\x2dserver\\x2ddata.mount" ];

    serviceConfig = {
      Type = "exec";
      # --rm removes the container automatically when it exits, keeping things clean.
      ExecStart = "/run/current-system/sw/bin/docker run --rm --name generic-server --network host -v /home/generic-user/generic-server-data:/data ghcr.io/example/generic-server:latest";
      # Sends graceful stop signal to the container. Adjust --time to match
      # however long the server needs to save/shutdown (e.g. 90 for PZ).
      ExecStop = "/run/current-system/sw/bin/docker stop --time 90 generic-server";
      # Must be higher than the --time value above so systemd doesn't SIGKILL
      # before Docker finishes the graceful stop.
      TimeoutStopSec = "120s";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = "PATH=/run/current-system/sw/bin:/run/wrappers/bin";
    };
  };

  # Restart daily at midnight.
  # systemctl restart calls ExecStop (graceful docker stop) then ExecStart,
  # so the server is always shut down cleanly before coming back up.
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
