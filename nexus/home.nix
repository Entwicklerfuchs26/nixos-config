{ config, pkgs, ... }:
{
  home-manager.users.fuchs = {
    home.username = "fuchs";
    home.homeDirectory = "/home/fuchs";
    home.stateVersion = "25.11";
    home.sessionVariables = {
      PATH = "$HOME/.local/bin:$PATH";
    };
    imports = [
      ./home/hyprland.nix
      ./home/waybar.nix
      ./home/kitty.nix
      ./home/matugen.nix
      ./home/skwd-wall.nix
      ./home/desktop.nix
    ];
    home.packages = with pkgs; [
      vivaldi
      obsidian
      vscode
      matugen
    ];
    programs.git = {
      enable = true;
      userName = "Entwicklerfuchs26";
      userEmail = "jonas@hofpause.info";
    };
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
