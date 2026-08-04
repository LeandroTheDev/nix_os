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
    pkgs.pkgsCross.gnu64.zlib  # java (emulated x86_64) needs libz.so.1 in BOX64_LD_LIBRARY_PATH
  ];

  # aarch64 libs needed by box64's native(wrapped) shims.
  # NixOS has no ldconfig/FHS search path, so these must be pointed at explicitly via the wrapper.
  nativeLibs = [
    pkgs.zlib
    pkgs.libsm
    pkgs.libice
    pkgs.libx11
    pkgs.libxext
  ];

  # Wrap box64 so LD_LIBRARY_PATH is always set regardless of how the user session was opened
  # (PAM, non-login shell, etc.). environment.sessionVariables only works for interactive login shells.
  box64Wrapped = pkgs.symlinkJoin {
    name = "box64-wrapped";
    paths = [ box64 ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/box64 \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath nativeLibs}
    '';
  };
in
{
  environment.systemPackages = [ box64Wrapped ] ++ i686Libs ++ x86_64Libs;

  # Use environment.variables (→ /etc/environment, read by PAM) instead of sessionVariables
  # (→ login shell only). This ensures BOX64_LD_LIBRARY_PATH is set for all sessions so
  # start-server-arm.sh's ${BOX64_LD_LIBRARY_PATH} expansion always includes the nix store paths.
  environment.variables.BOX64_LD_LIBRARY_PATH = ".:bin/:" + lib.makeLibraryPath (i686Libs ++ x86_64Libs);

  # When emulated x86_64 code (e.g. ProjectZomboid64) exec's another x86_64 binary (e.g. java),
  # the kernel tries to load the ELF interpreter at /lib64/ld-linux-x86-64.so.2 which doesn't
  # exist on NixOS. Registering box64 as the binfmt handler for x86_64 ELFs makes the kernel
  # redirect any x86_64 exec to box64 automatically, bypassing the FHS interpreter path entirely.
  boot.binfmt.registrations."box64-x86_64" = {
    interpreter = "${box64Wrapped}/bin/box64";
    # Matches x86_64 ELF binaries (64-bit, little-endian, machine=0x3e).
    magicOrExtension = "\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00";
    mask = "\\xff\\xff\\xff\\xff\\xff\\xfe\\xfe\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff";
    wrapInterpreterInShell = false;
    preserveArgvZero = false;
  };

  # box64 resolves the ELF interpreter and guest libraries for child execs by the exact FHS paths
  # in the binary's PT_INTERP / DT_NEEDED headers, which don't exist on NixOS.
  # Put the x86_64 cross-compiled libs in /lib64 so the x86_64 ld-linux (emulated) finds them.
  # Note: environment.sessionVariables requires re-login; tmpfiles takes effect on every rebuild.
  systemd.tmpfiles.rules = [
    "d /lib64 0755 root root - -"
    "L+ /lib64/ld-linux-x86-64.so.2 - - - - ${pkgs.pkgsCross.gnu64.glibc}/lib/ld-linux-x86-64.so.2"
    "L+ /lib64/libz.so.1 - - - - ${pkgs.pkgsCross.gnu64.zlib}/lib/libz.so.1"
  ];
}
