{ config, pkgs, ... }:
{
  home-manager.users.__GUEST_USER__ = {
    home.username    = "__GUEST_USER__";
    home.homeDirectory = "/home/__GUEST_USER__";
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
      settings.user.name  = "__GIT_NAME__";
      settings.user.email = "__GIT_EMAIL__";
    };
    programs.bash = {
      enable = true;
      shellAliases = {
        rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nexus-guest";
        update  = "sudo nix flake update /etc/nixos";
        config  = "cd /etc/nixos";
        ssh     = "TERM=xterm-256color ssh -t";
      };
      initExtra = ''
        if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
          export TERM=xterm-256color
        fi
      '';
    };
  };
}
