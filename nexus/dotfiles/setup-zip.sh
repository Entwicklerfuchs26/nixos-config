#!/usr/bin/env bash
set -e

ZIP="$1"

if [ -z "$ZIP" ]; then
  echo "Usage: setup-zip.sh <pfad-zur-zip>"
  exit 1
fi

echo "==> ZIP entpacken..."
sudo mkdir -p /etc/nixos
sudo unzip "$ZIP" -d /etc/nixos

echo "==> Install ausführen..."
bash /etc/nixos/nexus/dotfiles/install.sh
