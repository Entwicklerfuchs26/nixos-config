{ config, pkgs, ... }:

{
  # Affinity auf Wine (ElementalWarriorWine - gepatchter Wine-Fork für Affinity)
  # Setup: ~/scripts/affinity-setup.sh einmalig ausführen
  # Start:  ~/scripts/affinity.sh  oder  Affinity im App-Launcher
  environment.systemPackages = with pkgs; [
    winetricks
    p7zip    # für .tar.zst entpacken (vkd3d-proton)
    unzip    # für WinMetadata.zip
    zstd     # für .zst Entpacken
  ];
}
