{ config, pkgs, ... }:
{
  imports = [
    ./base.nix
    # ./nvidia.nix  ← wird vom install-friend.sh einkommentiert wenn NVIDIA erkannt
    ./hyprland.nix
    ./users-guest.nix   # generiert von install-friend.sh
    ./software.nix
    ./gaming.nix
    ./home-guest.nix    # generiert von install-friend.sh
    ./davinci.nix
    ./printing.nix
    ./ollama.nix
    ./docker-guest.nix
    ./affinity.nix
    # Bewusst weggelassen: ldap.nix, fuchs-shell.nix, sojus.nix
  ];
}
