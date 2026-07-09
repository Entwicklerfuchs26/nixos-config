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
      ./home/desktop.nix
      ./home/rofi.nix
      ./home/mimeapps.nix
    ];
    home.packages = with pkgs; [
      vivaldi
      obsidian
      vscode
      matugen
      mission-center
      (pkgs.callPackage ./pkgs/aniworld.nix { })
      (pkgs.callPackage ./pkgs/anime-organizer.nix { })
      (pkgs.callPackage ./pkgs/nix-manager.nix { })
    ];
    programs.git = {
      enable = true;
       settings.user.name = "Entwicklerfuchs26";
       settings.user.email = "jonas@hofpause.info";
    };
    programs.bash = {
      enable = true;
      shellAliases = {
        rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nexus";
        update = "sudo nix flake update /etc/nixos";
        config = "cd /etc/nixos";
        ssh = "TERM=xterm-256color ssh -t";
      };
      initExtra = ''
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
          export TERM=xterm-256color
       fi
      '';
    };
  };
}
