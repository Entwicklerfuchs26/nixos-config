{ config, pkgs, ... }:

{
  home-manager.users.fuchs = {
    home.username = "fuchs";
    home.homeDirectory = "/home/fuchs";
    home.stateVersion = "25.11";

    # Persönliche Pakete nur für deinen Benutzer
    home.packages = with pkgs; [
      vivaldi
      obsidian
      vscode
    ];

    # Git Konfiguration für deinen Benutzer
    programs.git = {
      enable = true;
      userName = "Entwicklerfuchs26";
      userEmail = "jonas@hofpause.info";
    };

    # Bash Konfiguration
    programs.bash = {
      enable = true;
      shellAliases = {
        rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nexus";
        update = "sudo nix flake update /etc/nixos";
        config = "cd /etc/nixos";
      };
    };
  };
}
