{ config, pkgs, ... }:
{
  home.file.".config/wlogout/style.css.templ".source = ./files/wlogout-style.css.templ;
  home.file.".config/nwg-dock-hyprland/style.css.templ".source = ./files/nwg-dock-style.css.templ;
  home.file.".config/OpenRGB/OpenRGB.json".source = ./files/OpenRGB.json;
  home.file.".config/gtk-3.0/settings.ini".source = ./files/gtk3-settings.ini;
  home.file.".config/gtk-4.0/settings.ini".source = ./files/gtk4-settings.ini;
  home.file.".icons/default/index.theme".source = ./files/cursor-index.theme;
}
