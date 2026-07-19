#!/usr/bin/env bash
# Nexus Recovery: stellt Jonass System nach einem Festplattencrash wieder her.
# Von einem NixOS-Live-USB ausführen (nixos-install muss verfügbar sein).
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[recovery]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}    $*"; }
die()   { echo -e "${RED}[fehler]${NC}  $*" >&2; exit 1; }
step()  { echo -e "\n${CYAN}══ $* ══${NC}"; }

REPO="https://github.com/Entwicklerfuchs26/nixos-config.git"

# ── Voraussetzungen ───────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Als root ausführen: sudo bash install-recovery.sh"
command -v nixos-install &>/dev/null || die "nixos-install nicht gefunden. Von NixOS-Live-USB booten!"
command -v git &>/dev/null || die "git nicht gefunden: nix-shell -p git"

step "Nexus Recovery – Festplattencrash"
echo ""
echo "Dieses Skript installiert Nexus frisch auf einer neuen Festplatte."
echo "Voraussetzung: neue Platte eingebaut, von NixOS-Live-USB gebootet."
echo ""

# ── Disk-Auswahl ──────────────────────────────────────────────────────────────
step "Festplatten-Setup"
echo "Verfügbare Laufwerke:"
lsblk -d -o NAME,SIZE,MODEL | grep -v "loop\|sr"
echo ""
read -rp "  Zieldisk (z.B. sda, nvme0n1): " DISK
DISK="/dev/${DISK}"
[[ -b "$DISK" ]] || die "Gerät $DISK nicht gefunden."

echo ""
warn "ACHTUNG: $DISK wird vollständig gelöscht!"
read -rp "  Wirklich $DISK formatieren? [ja/NEIN] " CONFIRM
[[ "$CONFIRM" == "ja" ]] || { echo "Abgebrochen."; exit 0; }

# ── Partitionierung ───────────────────────────────────────────────────────────
step "Partitionierung"

# EFI + Root (kein Swap – du hast genug RAM)
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 512MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart root ext4 512MiB 100%

# Partitions-Variablen (nvme hat p1/p2, SATA hat 1/2)
if [[ "$DISK" == *nvme* ]]; then
  PART_EFI="${DISK}p1"
  PART_ROOT="${DISK}p2"
else
  PART_EFI="${DISK}1"
  PART_ROOT="${DISK}2"
fi

info "Formatiere EFI: $PART_EFI"
mkfs.fat -F 32 -n EFI "$PART_EFI"

info "Formatiere Root: $PART_ROOT"
mkfs.ext4 -L nixos "$PART_ROOT"

# ── Einhängen ─────────────────────────────────────────────────────────────────
step "Partitionen einhängen"
mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot
mount "$PART_EFI" /mnt/boot
info "Gemountet: $PART_ROOT → /mnt, $PART_EFI → /mnt/boot"

# ── Hardware-Konfiguration generieren ─────────────────────────────────────────
step "Hardware-Konfiguration generieren"
nixos-generate-config --root /mnt
info "hardware-configuration.nix generiert."

# ── Repo klonen ───────────────────────────────────────────────────────────────
step "Nexus-Repo klonen"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git clone "$REPO" "$TMP/repo"
info "Repo geklont."

# ── Konfiguration nach /mnt/etc/nixos kopieren ────────────────────────────────
step "Konfiguration einrichten"
cp /mnt/etc/nixos/hardware-configuration.nix "$TMP/hw-config.nix"

# Recovery-Flake verwenden (kein sojus-core)
cp "$TMP/repo/flake-recovery.nix" "$TMP/repo/flake.nix"
info "flake-recovery.nix aktiviert (ohne sojus-core)."

# Repo nach /mnt/etc/nixos
rm -rf /mnt/etc/nixos
cp -r "$TMP/repo" /mnt/etc/nixos

# Eigene hardware-configuration.nix (nicht die aus dem Repo)
cp "$TMP/hw-config.nix" /mnt/etc/nixos/hardware-configuration.nix
info "hardware-configuration.nix von neuer Hardware eingefügt."

# ── nixos-install ─────────────────────────────────────────────────────────────
step "NixOS installieren (dauert lang...)"
echo ""
warn "Beim Start fragt NixOS nach dem root-Passwort – das kannst du direkt setzen."
echo ""
nixos-install --flake /mnt/etc/nixos#nexus

# ── Fertig / Post-Boot-Anleitung ──────────────────────────────────────────────
step "Installation abgeschlossen!"
echo ""
echo "  Jetzt neustarten: reboot"
echo ""
echo "  ─── Nach dem ersten Boot ───────────────────────────────────────────────"
echo ""
echo "  1. Als fuchs einloggen (LDAP-Login über darwin26.sternenhof.space)."
echo "     Falls LDAP nicht erreichbar: als root einloggen, dann:"
echo "     passwd fuchs"
echo ""
echo "  2. sojus-core wiederherstellen (aus Backup oder git):"
echo "     git clone <sojus-core-repo> /home/fuchs/sojus-core"
echo ""
echo "  3. agenix-Secret neu verschlüsseln (mit neuem SSH Host Key!):"
echo "     cd /etc/nixos/secrets"
echo "     cat /etc/ssh/ssh_host_ed25519_key.pub   # neuen Key notieren"
echo "     # secrets.nix anpassen, dann:"
echo "     agenix -r -i /etc/ssh/ssh_host_ed25519_key"
echo ""
echo "  4. flake.nix wiederherstellen (ersetzt flake-recovery.nix):"
echo "     cd /etc/nixos"
echo "     git checkout flake.nix"
echo "     rebuild"
echo ""
echo "  5. Fertig – volles System läuft wieder."
