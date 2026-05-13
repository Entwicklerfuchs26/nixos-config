{ config, pkgs,quickshell,awww, ... }:

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

environment.etc."sddm/themes/sddm-astronaut-theme/Themes/astronaut.conf".source = pkgs.writeText "astronaut.conf" ''
  [General]
  Background="Backgrounds/astronaut.png"
  DimBackground="0.3"
  PartialBlur="true"
  FormPosition="center"
  HourFormat="HH:mm"
  DateFormat="dddd d. MMMM"
  Font="JetBrains Mono"
  RoundCorners="20"
  ForceLastUser="true"
  PasswordFocus="true"
  HideCompletePassword="true"
  TranslateLogin="Anmelden"
  TranslateReboot="Neustart"
  TranslateShutdown="Herunterfahren"
  TranslateSuspend="Ruhezustand"
'';

}
