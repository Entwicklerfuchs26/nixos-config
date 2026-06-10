{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # Hostname
  networking.hostName = "nexus";
    networking.networkmanager.enable = true;
    networking.interfaces.enp5s0 = {
      wakeOnLan.enable = true;
    };

  security.sudo.extraRules = [{
    users = [ "fuchs" ];
    commands = [{
      command = "/run/current-system/sw/bin/shutdown";
      options = [ "NOPASSWD" ];
    }];
  }];

  #ssh
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;

  # Trusted CA (Sternenhof Root CA)
  security.pki.certificateFiles = [ ./certs/sternenhof-ca-2026.crt ];

  networking.hosts = {
      "192.168.1.26" = [ "cloud.sternenhof.space" ];
    };

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

services.udev.packages = [ pkgs.openrgb ];
boot.kernelModules = [ "btusb" "i2c-dev" ];

  system.stateVersion = "25.11";

users.groups.i2c = {};
services.udev.extraRules = ''
  KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
'';

}
