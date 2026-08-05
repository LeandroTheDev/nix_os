{ config, lib, pkgs, ... }:
{
  # Don't forget to add the group "docker" to the user you want to use docker

  virtualisation.docker = {
    enable = true;
  };
}
