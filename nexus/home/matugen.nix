{ config, pkgs, ... }:
{
  home.file.".config/matugen/config.toml".source = ./files/matugen-config.toml;
  home.file.".config/matugen/colors.sh.templ".source = ./files/matugen-colors.sh.templ;
  home.file.".config/matugen/hyprlock.conf.templ".source = ./files/hyprlock.conf.templ;
  home.file.".config/matugen/kdeglobals.templ".source = ./files/kdeglobals.templ;
  home.file.".config/matugen/apply-borders.sh" = {
    source = ./files/apply-borders.sh;
    executable = true;
  };
  home.file.".config/matugen/openrgb-apply.sh" = {
    source = ./files/openrgb-apply.sh;
    executable = true;
  };
  home.file.".config/matugen/papirus-color.sh" = {
    source = ./files/papirus-color.sh;
    executable = true;
  };
  home.file.".config/gtk-4.0/gtk.css.templ".source = ./files/gtk4.css.templ;
}
