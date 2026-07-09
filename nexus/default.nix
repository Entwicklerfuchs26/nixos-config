{ config, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./nvidia.nix
    ./hyprland.nix
    ./users.nix
    ./software.nix
    ./gaming.nix
    ./ldap.nix
    ./home.nix
    ./davinci.nix
    ./printing.nix
    ./ollama.nix
    ./docker.nix
    ./affinity.nix
  ];
}
