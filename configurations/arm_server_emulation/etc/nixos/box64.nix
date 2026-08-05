# Box64/Box32 binfmt emulation, adapted (non-flake) from
# https://github.com/Yeshey/nixos-box64-binfmt
{ pkgs, lib, ... }:

let
  # 32-bit x86 (i386/i686) is handled by box86.nix instead — binfmt_misc only
  # lets one handler own a given ELF magic, so Box32 stays off here.
  box64 = pkgs.box64;

  # Libraries Box64 has explicit C-wrappers for, see https://github.com/ptitSeb/box64/tree/main/src/wrapped
  nativeBox64Libs = with pkgs; [
    alsa-lib libpulseaudio libsndfile openal
    SDL2 SDL2_image SDL2_mixer SDL2_ttf SDL2_net
    SDL SDL_image SDL_mixer SDL_ttf SDL_net
    libGL libGLU vulkan-loader wayland
    xorg.libX11 xorg.libXext xorg.libXrandr xorg.libXrender xorg.libxcb
    xorg.libXfixes xorg.libXcomposite xorg.libXcursor xorg.libXdamage xorg.libXi
    xorg.libXinerama xorg.libXScrnSaver xorg.libSM xorg.libICE
    fontconfig freetype
    libdrm libvdpau libvorbis libogg
    gtk2 gtk3 glib dbus util-linux
  ];

  box64Wrapper = pkgs.writeShellScript "box64-wrapper" ''
    export BOX64_LD_LIBRARY_PATH="${lib.makeLibraryPath nativeBox64Libs}''${BOX64_LD_LIBRARY_PATH:+:$BOX64_LD_LIBRARY_PATH}"

    # Force software rendering for GL contexts since you have no hardware acceleration
    export LIBGL_ALWAYS_SOFTWARE=1

    exec ${box64}/bin/box64 "$@"
  '';
in
{
  boot.binfmt.preferStaticEmulators = false;

  boot.binfmt.registrations = {
    # 64-bit x86 ELF
    "x86_64-linux" = {
      interpreter            = "${box64Wrapper}";
      magicOrExtension       = ''\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00'';
      mask                   = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
      wrapInterpreterInShell = false;
      preserveArgvZero       = false;
      openBinary             = false;
    };
  };

  nix.settings.extra-platforms = [
    "x86_64-linux"
    "i686-linux"
    "i386-linux"
  ];

  environment.systemPackages = [ box64 ];

  nixpkgs.overlays = [
    (final: prev: {
      x86 = import pkgs.path {
        system = "x86_64-linux";
        config.allowUnfree = true;
        config.allowUnsupportedSystem = true;
      };
    })
  ];
}
