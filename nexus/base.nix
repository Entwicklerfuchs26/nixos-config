{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Hostname
  networking.hostName = "nexus";
  networking.networkmanager.enable = true;

  # Sprache und Zeitzone
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";

  # Drucker
  services.printing.enable = true;

  # Audio mit Pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Unfree Pakete erlauben (brauchen wir für NVIDIA)
  nixpkgs.config.allowUnfree = true;

  # Flakes aktivieren
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bluetooth
  hardware.enableAllFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

#  services.xserver.enable = true;

  # Display Manager
#  services.xserver.enable = true;
#  services.displayManager.sddm = {
#    enable = true;
#    wayland.enable = true;
#  };
#  services.displayManager.defaultSession = "hyprland";

services.udev.packages = [ pkgs.openrgb ];
boot.kernelModules = [ "btusb" "i2c-dev" ];

  system.stateVersion = "25.11";
}
