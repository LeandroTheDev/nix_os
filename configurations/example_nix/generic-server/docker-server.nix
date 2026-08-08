# Example systemd service for a Docker-based server with graceful shutdown.
# This template assumes a fixed, pre-existing container (created externally or
# via docker create). It uses "docker start -a" to attach to the container in
# the foreground so systemd can track the process, and "docker stop" for
# graceful shutdown. Do NOT use this template if you want Docker to manage the
# container lifecycle with "docker run --rm".
# When the service stops or restarts (including the daily midnight restart),
# systemd runs ExecStop first, which gives Docker time to shut the container
# down gracefully before killing anything.

{ ... }:

{
  systemd.services.generic-server = {
    description = "Generic Docker Server";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "network.target" ];
    requires = [ "docker.service" ];

    serviceConfig = {
      Type = "exec";
      # -a attaches stdout/stderr so systemd tracks the process in the foreground.
      # The container must already exist (created via docker create or externally).
      ExecStart = "/run/current-system/sw/bin/docker start -a generic-server";
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
