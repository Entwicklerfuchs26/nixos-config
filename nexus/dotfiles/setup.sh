#!/usr/bin/env bash
# Nexus Setup Script - skwd-wall & matugen initialisieren

DOTFILES="$(dirname "$0")"

echo "==> skwd-wall Config einrichten..."
mkdir -p ~/.config/skwd-wall/data/matugen/templates
mkdir -p ~/.config/skwd-wall/scripts

cp "$DOTFILES/skwd-wall/config.json" ~/.config/skwd-wall/
cp "$DOTFILES/skwd-wall/scripts/"* ~/.config/skwd-wall/scripts/
chmod +x ~/.config/skwd-wall/scripts/*.sh
cp "$DOTFILES/skwd-wall/templates/"* ~/.config/skwd-wall/data/matugen/templates/

echo "==> matugen Config einrichten..."
mkdir -p ~/.config/matugen
cp "$DOTFILES/matugen/config.toml" ~/.config/matugen/

cp "$DOTFILES/matugen/colors.sh.templ" ~/.config/matugen/
cp "$DOTFILES/matugen/kdeglobals.templ" ~/.config/matugen/
cp "$DOTFILES/matugen/hyprlock.conf.templ" ~/.config/matugen/
cp "$DOTFILES/matugen/apply-borders.sh" ~/.config/matugen/
cp "$DOTFILES/matugen/openrgb-apply.sh" ~/.config/matugen/
cp "$DOTFILES/matugen/papirus-color.sh" ~/.config/matugen/
chmod +x ~/.config/matugen/*.sh

echo "==> Fertig!"
