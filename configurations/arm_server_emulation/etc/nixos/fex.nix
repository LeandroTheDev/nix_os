# FEX (FEX-Emu) binfmt emulation, an alternative to box64.nix/box86.nix for
# running x86 and x86-64 ELF binaries on aarch64. See:
# https://mynixos.com/nixpkgs/package/fex
# https://github.com/FEX-Emu/FEX/blob/main/Data/binfmts/FEX-x86_64.in
# https://github.com/FEX-Emu/FEX/blob/main/Data/binfmts/FEX-x86.in
#
# binfmt_misc only lets one handler own a given ELF magic, so this file is
# NOT meant to be imported alongside box64.nix/box86.nix — pick FEX or the
# Box64/Box86 pair, not both, for a given architecture.
#
# Unlike Box64/Box86, FEX doesn't wrap native ARM64 libraries in place of the
# x86 ones — it needs a real x86/x86-64 RootFS (glibc, ld.so, etc.) to run
# guest binaries against. After enabling this module, fetch one with the
# `FEXRootFSFetcher` binary shipped in this package (interactive), or point
# FEX_ROOTFS at an existing RootFS directory.
{ pkgs, lib, ... }:

let
  fex = pkgs.fex;

  fexWrapper = pkgs.writeShellScript "fex-wrapper" ''
    exec ${fex}/bin/FEX "$@"
  '';
in
{
  boot.binfmt.preferStaticEmulators = false;

  boot.binfmt.registrations = {
    # 64-bit x86 ELF
    "x86_64-linux" = {
      interpreter            = "${fexWrapper}";
      magicOrExtension       = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'';
      mask                   = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\x00\x00\x00\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
      wrapInterpreterInShell = false;
      preserveArgvZero       = true;
      matchCredentials       = true;
      fixBinary              = true;
    };
    # 32-bit x86 (i386) ELF
    "i386-linux" = {
      interpreter            = "${fexWrapper}";
      magicOrExtension       = ''\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00'';
      mask                   = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\x00\x00\x00\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
      wrapInterpreterInShell = false;
      preserveArgvZero       = true;
      matchCredentials       = true;
      fixBinary              = true;
    };
  };

  nix.settings.extra-platforms = [
    "x86_64-linux"
    "i386-linux"
  ];

  environment.systemPackages = [ fex ];
}
