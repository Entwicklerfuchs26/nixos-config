{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Browser
    firefox

    # Editor
    kdePackages.kate

    # Terminal
    kitty

    # Dateiverwaltung
    kdePackages.dolphin

    # Archivierung
    kdePackages.ark

    # Grafik
    gimp
    inkscape

    # 3D
    blender

    # Kommunikation
    discord

    # Entwicklung
    git
    wget
    curl

    # System
    htop
    neofetch
  ];

  # Firefox als Programm aktivieren
  programs.firefox.enable = true;
}
