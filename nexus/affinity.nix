{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    winetricks
    wine
    wine64
  ];
}
