{ config, pkgs, ... }:

{
  # Steam aktivieren
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = false;
  };

  # GameMode - optimiert CPU beim Spielen
  programs.gamemode.enable = true;

  # Gaming Pakete
  environment.systemPackages = with pkgs; [
    # Proton für Windows-Spiele
    protonup-qt

    # MangoHud - FPS Anzeige im Spiel
    mangohud

    # Minecraft Launcher
    prismlauncher
  ];
}
