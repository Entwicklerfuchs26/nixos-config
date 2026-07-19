{ config, pkgs, ... }:
{
  users.mutableUsers = true;

  users.users.__GUEST_USER__ = {
    isNormalUser = true;
    description  = "__GUEST_USER__";
    extraGroups  = [ "wheel" "networkmanager" "audio" "video" "input" "bluetooth" "i2c" ];
    shell        = pkgs.bash;
    initialPassword = "nixos";
  };
}
