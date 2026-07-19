{ config, pkgs, ... }:
{
  # Bootstrap-Konfiguration nach Festplattencrash.
  # Identisch mit default.nix, aber ohne fuchs-shell.nix (braucht agenix-Secret)
  # und ohne sojus.nix (braucht /home/fuchs/sojus-core).
  # Nach erstem Boot: sojus-core wiederherstellen, Secret neu verschlüsseln,
  # dann zurück zu flake.nix wechseln.
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
    # Ohne: fuchs-shell.nix (Secret fehlt), sojus.nix (sojus-core fehlt)
  ];
}
