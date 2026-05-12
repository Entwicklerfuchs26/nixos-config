{ config, pkgs, ... }:

{
  # flatpak
  services.flatpak.enable = true;
  xdg.portal.enable = true;


  programs.kdeconnect.enable = true;
  programs.firefox.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  environment.systemPackages = with pkgs; [
    # Browser
    vivaldi

    # Editor & Dokumente
    kdePackages.kate
    libreoffice
    kdePackages.okular

    # Dateiverwaltung
    kdePackages.dolphin
    xarchiver

    # Bildbetrachtung
    kdePackages.gwenview

    # Grafik & 3D
    blender
    krita
    freecad

    # Media
    vlc
    handbrake
    obs-studio
    jellyfin-media-player

    # Musik & Spaß
    cava
    cmatrix

    # Kommunikation
    discord

    # Cloud & Sync
    nextcloud-client

    # Gaming
    prismlauncher

    # System
    htop
    fastfetch
    pavucontrol
    mission-center
    openrgb
    rpi-imager
    matugen
    ffmpeg

    # VPN
    # proton-vpn-gnome-desktop

    # Clipboard
    cliphist

    # Passwörter & Sicherheit
    bitwarden-desktop
    gnome-keyring
    seahorse

    # Entwicklung
    git
    wget
    curl

    # Schriften
    nerd-fonts.jetbrains-mono
    pavucontrol
    pipewire
    wireplumber
    pulseaudio
    wlogout

    # GTK Theme & Icons
    adw-gtk3
    papirus-icon-theme
    bibata-cursors
    kdePackages.breeze
    kdePackages.plasma-workspace-wallpapers
    kdePackages.qqc2-breeze-style
    kdePackages.plasma-integration
    kdePackages.qqc2-breeze-style
    papirus-folders

    # Qt Theming
    qt6Packages.qt6ct
    kdePackages.breeze
    libsForQt5.qt5ct
  ];

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "breeze";
  };
}
