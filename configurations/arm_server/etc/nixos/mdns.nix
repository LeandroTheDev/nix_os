{ config, pkgs, ... }:
{
  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        MulticastDNS = "no";
      };
    };
  };

  networking.networkmanager = {
    enable = true;
    connectionConfig = {
      "connection.mdns" = 0;
    };
  };

  services.avahi = {
    enable = true;
    ipv6 = false;
    nssmdns4 = true;
    openFirewall = true;
    reflector = true;

    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };
}