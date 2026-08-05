{ config, lib, pkgs, ... }:
{
  # Don't forget to add the group "docker" to the user you want to use docker

  # Workaround for https://github.com/NixOS/nixpkgs/issues/392673
  nixpkgs.overlays = [
    (final: previous: {
      nettle = previous.nettle.overrideAttrs (
        lib.optionalAttrs final.stdenv.hostPlatform.isStatic {
          CCPIC = "-fPIC";
        }
      );
    })
    (final: previous: {
      qemu-user = previous.qemu-user.overrideAttrs (
        old:
        lib.optionalAttrs final.stdenv.hostPlatform.isStatic {
          configureFlags = old.configureFlags ++ [ "--disable-pie" ];
        }
      );
    })
  ];

  boot.binfmt.emulatedSystems = [ "x86_64-linux" "i386-linux" "i686-linux" ];
  boot.binfmt.preferStaticEmulators = true;

  virtualisation.docker = {
    enable = true;
  };

  environment.shellAliases = {
    runx64 = "docker run --platform linux/amd64 --rm -it";
  };
}
