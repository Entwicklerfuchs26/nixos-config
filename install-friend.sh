#!/usr/bin/env bash
# Nexus-Setup für Freunde: klont das Repo und richtet Jonass Desktop-Konfiguration ein.
# Voraussetzung: NixOS bereits installiert und gebootet, Skript als normaler User ausführen.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[nexus]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
die()   { echo -e "${RED}[fehler]${NC} $*" >&2; exit 1; }
step()  { echo -e "\n${CYAN}══ $* ══${NC}"; }

REPO="https://github.com/Entwicklerfuchs26/nixos-config.git"

# ── Voraussetzungen ───────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Nicht als root ausführen – das Skript nutzt sudo selbst."
command -v nixos-rebuild &>/dev/null || die "nixos-rebuild nicht gefunden. Bist du auf NixOS?"
[[ -f /etc/nixos/hardware-configuration.nix ]] || die "Keine hardware-configuration.nix in /etc/nixos. NixOS zuerst installieren."

# git verfügbar?
command -v git &>/dev/null || die "git nicht gefunden. Bitte so starten:\n\n  nix-shell -p git --run 'bash /tmp/install.sh'"

step "Willkommen zum Nexus-Setup"
echo "Dieses Skript richtet Jonass NixOS-Konfiguration auf deinem Rechner ein."
echo "Du bekommst: Hyprland, alle Software, Gaming-Setup, Custom-Themes."
echo ""

# ── Eingaben ──────────────────────────────────────────────────────────────────
step "Konfiguration"

read -rp "  Dein Benutzername [fuchs]: " USERNAME
USERNAME="${USERNAME:-fuchs}"

read -rp "  Dein Name für Git []: " GIT_NAME
GIT_NAME="${GIT_NAME:-Unbekannt}"

read -rp "  Deine E-Mail für Git []: " GIT_EMAIL
GIT_EMAIL="${GIT_EMAIL:-user@example.com}"

echo ""
echo "  GPU-Typ:"
echo "    1) NVIDIA"
echo "    2) AMD"
echo "    3) Intel / andere"
read -rp "  Auswahl [1]: " GPU_CHOICE
GPU_CHOICE="${GPU_CHOICE:-1}"

echo ""
echo "  Zusammenfassung:"
echo "    Benutzername : $USERNAME"
echo "    Git-Name     : $GIT_NAME"
echo "    Git-Email    : $GIT_EMAIL"
echo "    GPU          : $(case $GPU_CHOICE in 1) echo NVIDIA;; 2) echo AMD;; *) echo Intel/andere;; esac)"
echo ""
read -rp "  Fortfahren? [J/n] " CONFIRM
[[ "${CONFIRM,,}" =~ ^(n|nein)$ ]] && { echo "Abgebrochen."; exit 0; }

# ── Hardware-Config sichern ───────────────────────────────────────────────────
step "Hardware-Konfiguration sichern"
HW_BACKUP=$(mktemp)
cp /etc/nixos/hardware-configuration.nix "$HW_BACKUP"
info "hardware-configuration.nix gesichert → $HW_BACKUP"

# ── Repo klonen ───────────────────────────────────────────────────────────────
step "Repo klonen"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

info "Klone $REPO ..."
git clone "$REPO" "$TMP/repo"
cd "$TMP/repo"

# ── hardware-configuration.nix einfügen ──────────────────────────────────────
cp "$HW_BACKUP" hardware-configuration.nix
info "hardware-configuration.nix eingefügt."

# ── flake-guest.nix aktivieren ────────────────────────────────────────────────
step "Gast-Flake aktivieren"
cp flake-guest.nix flake.nix
info "flake-guest.nix → flake.nix"

# ── users-guest.nix generieren ────────────────────────────────────────────────
step "User-Konfiguration generieren"
sed "s/__GUEST_USER__/${USERNAME}/g" nexus/users-guest.template.nix > nexus/users-guest.nix
info "users-guest.nix erstellt (User: $USERNAME, Passwort: nixos)"

# ── home-guest.nix generieren ────────────────────────────────────────────────
sed \
  -e "s/__GUEST_USER__/${USERNAME}/g" \
  -e "s/__GIT_NAME__/${GIT_NAME}/g" \
  -e "s/__GIT_EMAIL__/${GIT_EMAIL}/g" \
  nexus/home-guest.template.nix > nexus/home-guest.nix
info "home-guest.nix erstellt."

# ── NVIDIA-Modul aktivieren / weglassen ───────────────────────────────────────
step "GPU-Konfiguration"
if [[ "$GPU_CHOICE" == "1" ]]; then
  # nvidia.nix einkommentieren (entferne das '# ' vor der Zeile)
  sed -i 's|^    # \./nvidia\.nix.*|    ./nvidia.nix|' nexus/default-guest.nix
  info "nvidia.nix aktiviert."
else
  info "nvidia.nix bleibt deaktiviert (AMD/Intel)."
fi

# ── /etc/nixos ersetzen ───────────────────────────────────────────────────────
step "/etc/nixos einrichten"
warn "Das ersetzt den Inhalt von /etc/nixos (außer hardware-configuration.nix)."
read -rp "  Wirklich fortfahren? [J/n] " CONFIRM2
[[ "${CONFIRM2,,}" =~ ^(n|nein)$ ]] && { echo "Abgebrochen."; exit 0; }

# Altes /etc/nixos sichern
NIXOS_BACKUP="/etc/nixos.bak.$(date +%Y%m%d_%H%M%S)"
sudo mv /etc/nixos "$NIXOS_BACKUP"
info "Altes /etc/nixos gesichert → $NIXOS_BACKUP"

# Neues Verzeichnis anlegen und Dateien kopieren
sudo cp -r "$TMP/repo" /etc/nixos
sudo cp "$HW_BACKUP" /etc/nixos/hardware-configuration.nix
# .git entfernen – ohne Repo meckert Nix nicht über ungetrackte Dateien
sudo rm -rf /etc/nixos/.git
sudo chown -R "${USER}:users" /etc/nixos
info "Nexus-Konfiguration nach /etc/nixos kopiert."

# ── NixOS rebuild ─────────────────────────────────────────────────────────────
step "NixOS rebuild (das dauert beim ersten Mal lange...)"
sudo nixos-rebuild switch --flake /etc/nixos#nexus-guest

# ── skwd-wall Konfiguration deployen ─────────────────────────────────────────
# Wird NICHT von home-manager verwaltet – skwd-wall schreibt diese Dateien selbst.
step "skwd-wall Konfiguration einrichten"
USERHOME="/home/${USERNAME}"
SKWD_SRC="/etc/nixos/nexus/dotfiles/skwd-wall"

mkdir -p "${USERHOME}/.config/skwd-wall/scripts"
mkdir -p "${USERHOME}/.config/skwd-wall/data/matugen/templates"

# config.json: /home/fuchs/ → tatsächliches Home-Verzeichnis ersetzen
sed "s|/home/fuchs/|${USERHOME}/|g" \
    "${SKWD_SRC}/config.json" \
    > "${USERHOME}/.config/skwd-wall/config.json"

# Skripte deployen: /home/fuchs/ ersetzen, ausführbar machen
for SCRIPT in "${SKWD_SRC}/scripts/"*.sh; do
  DEST="${USERHOME}/.config/skwd-wall/scripts/$(basename "$SCRIPT")"
  sed "s|/home/fuchs/|${USERHOME}/|g; s|/run/user/1000/|/run/user/$(id -u ${USERNAME} 2>/dev/null || echo 1000)/|g" \
      "$SCRIPT" > "$DEST"
  chmod +x "$DEST"
done

# Templates deployen (keine Pfad-Ersetzung nötig)
cp "${SKWD_SRC}/templates/"* "${USERHOME}/.config/skwd-wall/data/matugen/templates/"

# Eigentümer setzen
chown -R "${USERNAME}:users" "${USERHOME}/.config/skwd-wall" 2>/dev/null || true

info "skwd-wall Konfiguration eingerichtet."

# ── Fertig ────────────────────────────────────────────────────────────────────
step "Fertig!"
echo ""
echo "  Dein System ist eingerichtet."
echo ""
echo "  Anmelden als : $USERNAME"
echo "  Passwort     : nixos"
echo ""
warn "Passwort sofort ändern: passwd"
echo ""
echo "  Alias 'rebuild' baut das System neu wenn du was änderst."
echo "  Konfiguration liegt in /etc/nixos"
