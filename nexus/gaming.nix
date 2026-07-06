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

  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-uuid/5abc4798-aa86-48c6-bf31-64206749f67d";
    fsType = "ext4";
    options = [ "defaults" "nofail" "noauto" "x-systemd.automount" "x-systemd.device-timeout=5" ];
  };
}
