{ config, pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  hardware.uinput.enable = true;

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
      "192.168.1.26" = [
        "cloud.sternenhof.space"
        "n8n.sternenhof.space"
        "media.sternenhof.space"
        "photos.sternenhof.space"
        "tasks.sternenhof.space"
        "home.sternenhof.space"
        "ntfy.sternenhof.space"
        "zugang.sternenhof.space"
        "darwin26.sternenhof.space"
      ];
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

    wireplumber.extraConfig."51-bluez-bose-a2dp" = {
      "monitor.bluez.rules" = [
        {
          matches = [
            { "device.name" = "bluez_card.7C_96_D2_77_56_7E"; }
          ];
          actions = {
            update-props = {
              "bluez5.auto-connect" = [ "a2dp_sink" ];
              "device.profile" = "a2dp-sink";
            };
          };
        }
      ];
    };
  };

  # Unfree Pakete erlauben (brauchen wir für NVIDIA)
  nixpkgs.config.allowUnfree = true;

  # Flakes aktivieren
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bluetooth
  hardware.enableAllFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings = {
    General = {
      Experimental = true;
      ReconnectAttempts = 7;
      ReconnectIntervals = "1,2,4,8,16,32,64";
    };
  };

services.udev.packages = [ pkgs.openrgb ];
boot.kernelModules = [ "btusb" "i2c-dev" ];

  system.stateVersion = "25.11";

  # nix-ld: ermöglicht dynamisch gelinkte Binaries (z.B. patchright/Playwright)
  programs.nix-ld.enable = true;

users.groups.i2c = {};
services.udev.extraRules = ''
  KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  # Intel AX200 Bluetooth USB-Autosuspend deaktivieren (verhindert zufälliges Verschwinden)
  ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0029", ATTR{power/autosuspend}="-1"
'';

# iPhone Mounting
  services.usbmuxd.enable = true;

# Festplatten-Erkennung & Mounting
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  boot.supportedFilesystems = [ "ntfs" ];
  # Kernel-exFAT deaktiviert → fuse-exfat übernimmt (uid/gid funktioniert)
  boot.blacklistedKernelModules = [ "exfat" ];
  environment.systemPackages = with pkgs; [ udisks2 exfat ];
  # exFAT via fuse-exfat mit korrekter Besitzer-Zuweisung mounten
  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    exfat_defaults=uid=$UID,gid=$GID,umask=002
    exfat_allow=uid=$UID,gid=$GID,umask,dmask,fmask,iocharset,errors
  '';

  # 1 TB Datenfestplatte (alte Linux-Installation, sdc2)
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/299df179-7040-42b8-a6f0-548247cc82f6";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" ];
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.isInGroup("wheel") &&
        action.id.indexOf("org.freedesktop.udisks2.") == 0
      ) {
        return polkit.Result.YES;
      }
    });
  '';

networking.firewall.allowedTCPPorts = [ 8080 8081 8888 7777 ];
}
