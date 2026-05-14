{ config, pkgs, ... }:
{
  home.file.".config/waybar/config.jsonc".source = ./files/waybar-config.jsonc;
  home.file.".config/waybar/style.css.templ".source = ./files/waybar-style.css.templ;
}
