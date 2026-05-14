{ config, pkgs, ... }:
{
  home.file.".config/skwd-wall/config.json".source = ./files/skwd-wall-config.json;
}
