{ config, pkgs, ... }:
{
  home.file.".config/hypr/hyprland.conf".source = ./files/hyprland.conf;
}

