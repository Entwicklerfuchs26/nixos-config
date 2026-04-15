{ config, pkgs, ... }:

{
  # X11 und Wayland aktivieren
  services.xserver.enable = true;

  # KDE Plasma 6 mit SDDM
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  # Tastaturlayout
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };
  console.keyMap = "de";


  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
}
