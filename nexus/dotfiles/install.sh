#!/usr/bin/env bash
set -e

DOTFILES="$(dirname "$0")"

echo "==> [1/4] NixOS Config einrichten..."
sudo cp -r "$DOTFILES/../" /etc/nixos/nexus/

echo "==> [2/4] NixOS rebuild..."
sudo nixos-rebuild switch --flake /etc/nixos#nexus

echo "==> [3/4] skwd-wall einrichten..."
mkdir -p ~/.config/skwd-wall/data/matugen/templates
mkdir -p ~/.config/skwd-wall/scripts
cp "$DOTFILES/skwd-wall/config.json" ~/.config/skwd-wall/
cp "$DOTFILES/skwd-wall/scripts/"* ~/.config/skwd-wall/scripts/
chmod +x ~/.config/skwd-wall/scripts/*.sh
cp "$DOTFILES/skwd-wall/templates/"* ~/.config/skwd-wall/data/matugen/templates/

echo "==> [4/4] matugen einrichten..."
mkdir -p ~/.config/matugen
cp "$DOTFILES/matugen/"* ~/.config/matugen/
chmod +x ~/.config/matugen/*.sh

echo "==> Fertig! Bitte neu einloggen."
