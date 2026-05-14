{ config, pkgs, ... }:
{
  home.file.".config/skwd-wall/config.json".source = ./files/skwd-wall-config.json;
  home.file.".config/skwd-wall/data/matugen/templates/waybar.css".source = ./files/skwd-waybar.css;
  home.file.".config/skwd-wall/data/matugen/templates/kitty.conf".source = ./files/skwd-kitty.conf;
  home.file.".config/skwd-wall/data/matugen/templates/wlogout.css".source = ./files/skwd-wlogout.css;
  home.file.".config/skwd-wall/data/matugen/templates/nwg-dock.css".source = ./files/skwd-nwg-dock.css;
  home.file.".config/skwd-wall/data/matugen/templates/kdeglobals.conf".source = ./files/skwd-kdeglobals.conf;
}
