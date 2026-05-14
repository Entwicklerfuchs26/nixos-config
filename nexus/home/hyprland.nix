{ config, pkgs, ... }:
{
  home.file.".config/hypr/hyprland.conf".source = ./files/hyprland.conf;
  home.file.".config/hypr/hyprlock.conf".source = ./files/hyprlock.conf;
  home.file.".config/hypr/hypridle.conf".source = ./files/hypridle.conf;
}

