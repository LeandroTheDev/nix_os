{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # System
    vim
    wget
    curl
    sudo
    htop
    # Server
    tmux
    git
    unzip
    box64
    box86
    # Debug
    file
    binutils
  ];
}
