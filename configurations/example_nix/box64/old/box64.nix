{ pkgs, lib, ... }:

let
  box64 = pkgs.box64.overrideAttrs (oldAttrs: {
    version = "main";
    src = pkgs.fetchFromGitHub {
      owner = "ptitSeb";
      repo = "box64";
      rev = "main";
      sha256 = "sha256-ZTKOioqvBcfLsXlEa8hJIxVxQaOPjhpJlibRQZgp0qU=";
    };
    enableParallelBuilding = false;
    patches = (oldAttrs.patches or []) ++ [
      #./box64-pthread-clockwait.patch
      #./box64-dlinfo32-linkmap.patch
      #./box64-debug-tolong.patch
    ];
    dontStrip = true;
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DRPI4ARM64=1"
      "-DBOX32=ON"
      "-DBOX32_BINFMT=ON"
      "-DCMAKE_BUILD_TYPE=Release"
    ];
  });

  i686Libs = [
    pkgs.pkgsCross.gnu32.stdenv.cc.cc.lib
    pkgs.pkgsCross.gnu32.glibc
  ];
in
{
  environment.systemPackages = [ box64 ] ++ i686Libs;

  environment.sessionVariables.BOX64_LD_LIBRARY_PATH = ".:bin/:" + lib.makeLibraryPath i686Libs;
}
