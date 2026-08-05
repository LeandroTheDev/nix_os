# Box86 binfmt emulation for 32-bit x86 (i386/i686) — mirrors the box64.nix
# treatment. Box64's own Box32 support stays disabled so the two emulators
# don't fight over the same binfmt_misc magic.
{ pkgs, lib, ... }:

let
  box86 = pkgs.box86;

  # Libraries Box86 has explicit C-wrappers for, see https://github.com/ptitSeb/box86/tree/master/src/wrapped
  nativeBox86Libs = with pkgs; [
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

  box86Wrapper = pkgs.writeShellScript "box86-wrapper" ''
    export BOX86_LD_LIBRARY_PATH="${lib.makeLibraryPath nativeBox86Libs}''${BOX86_LD_LIBRARY_PATH:+:$BOX86_LD_LIBRARY_PATH}"

    # Force software rendering for GL contexts since you have no hardware acceleration
    export LIBGL_ALWAYS_SOFTWARE=1

    exec ${box86}/bin/box86 "$@"
  '';
in
{
  boot.binfmt.registrations = {
    # 32-bit x86 ELF
    "i386-linux" = {
      interpreter            = "${box86Wrapper}";
      magicOrExtension       = ''\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x03\x00'';
      mask                   = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
      wrapInterpreterInShell = false;
      preserveArgvZero       = false;
      openBinary             = false;
    };
    # i686/i486/i586 ELFs
    "i686-linux" = {
      interpreter            = "${box86Wrapper}";
      magicOrExtension       = ''\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x06\x00'';
      mask                   = ''\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'';
      wrapInterpreterInShell = false;
      preserveArgvZero       = false;
      openBinary             = false;
    };
  };

  environment.systemPackages = [ box86 ];
}
