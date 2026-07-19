{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
  # nvidia-container-toolkit und users.users.fuchs weggelassen –
  # Guest-User wird in users-guest.nix zur docker-Gruppe hinzugefügt.
}
