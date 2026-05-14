{ config, pkgs, ... }:
{
  home.file.".config/kitty/kitty.conf".source = ./files/kitty.conf;
}

