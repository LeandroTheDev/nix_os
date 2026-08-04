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

  # 64bit x86_64 counterpart of i686Libs, for guest programs like Project Zomboid's
  # ProjectZomboid64 launcher (needs libstdc++.so.6 / libgcc_s.so.1 in 64bit).
  x86_64Libs = [
    pkgs.pkgsCross.gnu64.stdenv.cc.cc.lib
    pkgs.pkgsCross.gnu64.glibc
  ];

  # aarch64 libs needed by box64's native(wrapped) libc/libbsd shims (e.g. libz.so.1).
  # NixOS has no ldconfig/FHS search path, so these must be pointed at explicitly.
  nativeLibs = [
    pkgs.zlib
  ];
in
{
  environment.systemPackages = [ box64 ] ++ i686Libs ++ x86_64Libs ++ nativeLibs;

  environment.sessionVariables.BOX64_LD_LIBRARY_PATH = ".:bin/:" + lib.makeLibraryPath (i686Libs ++ x86_64Libs);
  environment.sessionVariables.LD_LIBRARY_PATH = lib.makeLibraryPath nativeLibs;
}
