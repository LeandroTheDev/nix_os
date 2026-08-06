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
    # Debug
    file
    binutils
  ];
}
