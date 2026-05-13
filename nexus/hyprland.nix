{ config, pkgs,quickshell,awww, ... }:

let
  sddm-theme = pkgs.runCommand "sddm-astronaut-patched" {} ''
    mkdir -p $out/share/sddm/themes
    cp -r ${pkgs.sddm-astronaut}/share/sddm/themes/sddm-astronaut-theme $out/share/sddm/themes/
    chmod -R +w $out/share/sddm/themes/sddm-astronaut-theme
    cat > $out/share/sddm/themes/sddm-astronaut-theme/Themes/astronaut.conf << 'CONF'
[General]
Background=Backgrounds/astronaut.png
DimBackground=0.3
PartialBlur=true
FormPosition=center
HourFormat=HH:mm
DateFormat=dddd d. MMMM
Font=JetBrains Mono
RoundCorners=20
ForceLastUser=true
PasswordFocus=true
HideCompletePassword=true
TranslateLogin=Anmelden
TranslateReboot=Neustart
TranslateShutdown=Herunterfahren
TranslateSuspend=Ruhezustand
CONF
  '';
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
    kdePackages.kirigami
    kdePackages.qqc2-breeze-style
  ];

environment.sessionVariables = {
  QML2_IMPORT_PATH = "${pkgs.kdePackages.kirigami}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml";
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

}
