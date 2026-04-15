{ config, pkgs, ... }:

{
  imports = [
    ./base.nix
    ./nvidia.nix
    ./kde.nix
    ./users.nix
    ./software.nix
    ./gaming.nix
    ./ldap.nix
  ];
}
