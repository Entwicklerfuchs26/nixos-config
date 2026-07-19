{ config, pkgs, ... }:

{
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };

  users.users.fuchs.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}
