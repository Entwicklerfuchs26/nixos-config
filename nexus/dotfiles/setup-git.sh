#!/usr/bin/env bash
set -e

REPO="https://github.com/Entwicklerfuchs26/nixos-config.git"
TARGET="/etc/nixos"

echo "==> Repo clonen..."
sudo git clone "$REPO" "$TARGET"

echo "==> Install ausführen..."
bash "$TARGET/nexus/dotfiles/install.sh"
