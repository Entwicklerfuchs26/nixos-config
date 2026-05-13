{ config, pkgs,quickshell,awww, ... }:

let
  sddm-theme = pkgs.sddm-astronaut.override {
    themeConfig = {
      Background = "Backgrounds/astronaut.png";
      PartialBlur = "true";
      DimBackground = "0.3";
      FormPosition = "center";
      HourFormat = "HH:mm";
      DateFormat = "dddd d. MMMM";
      Font = "JetBrains Mono";
      RoundCorners = "20";
      ForceLastUser = "true";
      PasswordFocus = "true";
      HideCompletePassword = "true";
      TranslateLogin = "Anmelden";
      TranslateReboot = "Neustart";
      TranslateShutdown = "Herunterfahren";
      TranslateSuspend = "Ruhezustand";
    };
  };
in

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = false;
  };

services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
  theme = "sddm-astronaut-theme";
  extraPackages = [ sddm-theme ];
};
services.displayManager.defaultSession = "hyprland";

  services.xserver = {
    enable = true;
    xkb.layout = "de";
    xkb.variant = "";
  };

  console.keyMap = "de";

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    hyprlock
    hypridle
    awww.packages.${pkgs.system}.default
    waybar
    nwg-dock-hyprland
    nwg-displays
    wofi
    kitty
    swaynotificationcenter
    libnotify
    wl-clipboard
    brightnessctl
    playerctl
    mpvpaper
    wlogout
    networkmanagerapplet
    xdg-desktop-portal-hyprland
    grim
    slurp
    polkit_gnome
    quickshell.packages.x86_64-linux.default
    qt6.qtmultimedia
    kdePackages.sddm-kcm
    sddm-astronaut
  ];

environment.sessionVariables = {
QML2_IMPORT_PATH = "${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
};


};
