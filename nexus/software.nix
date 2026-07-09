{ config, pkgs, ... }:

let
  userPackages = import ./user-packages.nix { inherit pkgs; };
in {
  # flatpak
  services.flatpak.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "hyprland;gtk";
  };


  programs.firefox.enable = true;
  programs.kdeconnect.enable = true;

programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      droidcam-obs
    ];
  };

  environment.systemPackages = with pkgs; [
    # Browser
    vivaldi

    # Editor & Dokumente
    kdePackages.kate
    libreoffice
    kdePackages.okular

    # Dateiverwaltung
    nautilus
    nautilus-python
    file-roller
    kdePackages.ark
    xarchiver

    # Vorschaubilder in Nautilus (Video, Dokumente)
    ffmpegthumbnailer

    # Bildbetrachtung
    kdePackages.gwenview

    # Grafik & 3D
    blender
    krita
    freecad
    darktable

    # Media
    vlc
    handbrake
    jellyfin-media-player

    # Musik & Spaß
    cava
    cmatrix

    # Kommunikation
    vesktop


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
    proton-vpn

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
    nodejs

    # Wissensfestplatte
    kiwix-tools

    # Schriften (nur für systemPackages; für fontconfig → fonts.packages unten)
    pipewire
    wireplumber
    pulseaudio
    wlogout

    # GTK Theme & Icons
    adw-gtk3
    papirus-icon-theme
    bibata-cursors
    kdePackages.breeze
    kdePackages.plasma-integration
    kdePackages.qqc2-breeze-style
    papirus-folders
    gtk3
    pwvucontrol
    rofi

    # Qt Theming
    qt6Packages.qt6ct
    libsForQt5.qt5ct
    imagemagick
 
    shared-mime-info
    xdg-utils

    # iPhone
    libimobiledevice
    ifuse

    # Widgets
    eww

    # KI / AI
    claude-code

    # Python
    python3
    pipx
    uv
  ] ++ userPackages;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "breeze";
  };
}
