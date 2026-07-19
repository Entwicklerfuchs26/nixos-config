{ config, pkgs, lib, quickshell, awww, skwd-daemon, ... }:

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
    kdePackages.kirigami
    kdePackages.qqc2-breeze-style
    kdePackages.kirigami
    skwd-daemon.packages.x86_64-linux.default
    qt6.qtimageformats
  ];

environment.sessionVariables = {
  QML2_IMPORT_PATH = "${pkgs.kdePackages.kirigami}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
  XDG_CURRENT_DESKTOP = "Hyprland";
};

environment.etc."sddm.conf.d/theme.conf".text = ''
  [Theme]
  Current=sddm-astronaut-theme
  ThemeDir=/run/current-system/sw/share/sddm/themes
  CursorTheme=Bibata-Modern-Classic
  CursorSize=24
'';

environment.etc."sddm/themes/sddm-astronaut-theme/Themes/astronaut.conf".text = ''
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


programs.skwd-wall.enable = true;

}
