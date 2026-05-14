{ config, pkgs, ... }:
{
  home.file.".config/hypr/hyprlock.conf".source = ./files/hyprlock.conf;
  home.file.".config/hypr/hypridle.conf".source = ./files/hypridle.conf;
  home.file.".config/wlogout/style.css.templ".source = ./files/wlogout-style.css.templ;
  home.file.".config/nwg-dock-hyprland/style.css.templ".source = ./files/nwg-dock-style.css.templ;
  home.file.".config/OpenRGB/OpenRGB.json".source = ./files/OpenRGB.json;
}
