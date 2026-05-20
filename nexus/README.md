# Nexus - NixOS Configuration

Meine persönliche NixOS Konfiguration mit Hyprland, adaptivem Theming via matugen und skwd-wall.

## Hardware
- ASUS ROG B550-F Gaming WIFI
- AMD Ryzen 7 3700X
- NVIDIA RTX 2070 SUPER
- 32GB RAM
- 3 Monitore (144Hz + 60Hz + 60Hz)

## Features
- Hyprland als Window Manager
- Adaptives Wallpaper-Theming via skwd-wall + matugen
- Waybar, SwayNC, Wofi, Wlogout
- OpenRGB LED Synchronisation mit Wallpaper-Farben
- Home Manager für deklarative Dotfile-Verwaltung

## Setup
Frische Installation:
\`\`\`bash
bash <(curl -s https://raw.githubusercontent.com/Entwicklerfuchs26/nixos-config/main/nexus/dotfiles/setup-git.sh)
\`\`\`

## Struktur
- `nexus/` - NixOS Konfiguration
- `nexus/home/` - Home Manager Module
- `nexus/dotfiles/` - Dotfiles und Setup-Scripts
