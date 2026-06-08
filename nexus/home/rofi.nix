{ config, pkgs, ... }:
{
  home.file.".config/rofi/config.rasi".source = ./files/rofi-config.rasi;
  home.file.".config/rofi/theme.rasi.templ".source = ./files/rofi-theme.rasi.templ;
}
