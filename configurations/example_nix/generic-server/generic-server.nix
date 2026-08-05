# This is a script for you as example for a automatic process
# that starts with the system and automatically restarts at 00:00

{ ... }:

{
  systemd.services.generic-server = {
    description = "Generic Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

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

  # Optional: Restart on 00:00
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
