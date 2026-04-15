{ config, pkgs, ... }:

{
  # Passwörter dürfen nur über NixOS verwaltet werden
  users.mutableUsers = true;

  # Dein Hauptbenutzer
  users.users.fuchs = {
    isNormalUser = true;
    description = "Entwicklerfuchs";
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
    ];
    shell = pkgs.bash;
  };

  # Sudo ohne Passwort für dich (optional, kannst du weglassen)
  # security.sudo.wheelNeedsPassword = true;
}
