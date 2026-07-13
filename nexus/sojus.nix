{ config, pkgs, lib, ... }:

let
  safeRebuildScript = pkgs.writeShellScript "safe-rebuild" ''
    #!/usr/bin/env bash
    set -euo pipefail

    DESCRIPTION="''${1:-auto}"
    FLAKE_DIR="/etc/nixos"
    FLAKE_TARGET="''${2:-nexus}"

    log() { echo "[safe-rebuild] $*"; }
    die() { echo "[safe-rebuild] FEHLER: $*" >&2; exit 1; }

    # git als root; safe.directory + expliziter Autor da root != Repo-Eigentümer
    git_fuchs() {
      git -C "$FLAKE_DIR" \
        -c safe.directory="$FLAKE_DIR" \
        -c user.name="Sojus-Agent" \
        -c user.email="sojus@nexus" \
        "$@"
    }

    log "Starte sicheren Rebuild: '$DESCRIPTION'"

    # libgit2 (intern in nix) prüft Repo-Eigentümer – root braucht safe.directory
    git config --global --add safe.directory "$FLAKE_DIR" 2>/dev/null || true

    # ── Pre-rebuild commit ────────────────────────────────────────────────────
    log "Staging alle Änderungen..."
    git_fuchs add -A

    # Nur committen wenn es tatsächlich Änderungen gibt
    if git_fuchs diff --cached --quiet; then
      log "Keine Änderungen im Staging – kein pre-rebuild commit nötig."
    else
      git_fuchs commit -m "pre-rebuild: $DESCRIPTION"
      log "Pre-rebuild commit erstellt."
    fi

    # ── Testbuild (build-vm) ──────────────────────────────────────────────────
    log "Baue VM-Test-Image..."
    sudo nixos-rebuild build-vm --flake "$FLAKE_DIR#$FLAKE_TARGET" \
      || die "build-vm fehlgeschlagen – switch abgebrochen."
    log "VM-Build erfolgreich."

    # ── Switch ────────────────────────────────────────────────────────────────
    log "Führe nixos-rebuild switch durch..."
    sudo nixos-rebuild switch --flake "$FLAKE_DIR#$FLAKE_TARGET" \
      || die "switch fehlgeschlagen – System im alten Zustand."
    log "Switch erfolgreich."

    # ── Post-rebuild commit ───────────────────────────────────────────────────
    git_fuchs add -A
    if git_fuchs diff --cached --quiet; then
      git_fuchs commit --allow-empty -m "post-rebuild: $DESCRIPTION – erfolgreich"
    else
      git_fuchs commit -m "post-rebuild: $DESCRIPTION – erfolgreich"
    fi
    log "Fertig. System läuft auf neuem Build."
  '';

in {
  # ── Sojus Agent User ─────────────────────────────────────────────────────────
  # Echter Login-fähiger User (kein isSystemUser) damit sudo -u sojus -s geht.
  # Kein Passwort gesetzt – Zugriff ausschließlich via: sudo -u sojus -s
  users.groups.sojus = {};

  users.users.sojus = {
    isNormalUser = true;
    description  = "Sojus KI-Agent";
    group        = "sojus";
    home         = "/home/sojus";
    createHome   = true;
    shell        = pkgs.bash;
    # Kein initialPassword / passwordFile → Login nur via sudo -u sojus -s
  };

  # ── ACL-Tools verfügbar halten ────────────────────────────────────────────────
  # setfacl/getfacl für /home/fuchs ACL-Verwaltung (imperativ nach Rebuild)
  environment.systemPackages = with pkgs; [ acl ];

  # ── safe-rebuild.sh deployen via Activation Script ───────────────────────────
  # Wird bei jedem nixos-rebuild switch aktuell gehalten.
  # Schreibt aus dem Nix-Store nach /home/sojus/bin/safe-rebuild.sh
  system.activationScripts.sojusBin = {
    deps = [ "users" ];
    text = ''
      install -d -m 750 -o sojus -g sojus /home/sojus/bin
      install -m 750 -o sojus -g sojus \
        ${safeRebuildScript} \
        /home/sojus/bin/safe-rebuild.sh
    '';
  };

  # ── Sudoers-Whitelist für sojus ───────────────────────────────────────────────
  # Nur diese Befehle sind erlaubt – alles andere ist DENY by default.
  # Explizit NICHT erlaubt (nicht gelistet): dd, mkfs, parted, userdel,
  #   passwd (für andere User), rm -rf auf Systempfade, shutdown, poweroff.
  security.sudo.extraRules = [
    {
      users = [ "sojus" ];
      commands = [
        # systemctl: nur restart/status für Sojus-relevante Services (mit und ohne Flags)
        {
          command = "/run/current-system/sw/bin/systemctl restart sojus-core";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart sojus-core *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status sojus-core";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status sojus-core *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart fuchs-shell";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart fuchs-shell *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status fuchs-shell";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status fuchs-shell *";
          options = [ "NOPASSWD" ];
        }

        # nixos-rebuild: nur build/build-vm/switch, mit optionalen Flags
        {
          command = "/run/current-system/sw/bin/nixos-rebuild build";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild build *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild build-vm";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild build-vm *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild switch";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nixos-rebuild switch *";
          options = [ "NOPASSWD" ];
        }

        # Wrapper-Skript (einziger empfohlener Rebuild-Einstiegspunkt)
        {
          command = "/home/sojus/bin/safe-rebuild.sh";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/home/sojus/bin/safe-rebuild.sh *";
          options = [ "NOPASSWD" ];
        }

        # git als fuchs – wird vom safe-rebuild.sh intern via sudo -u fuchs genutzt
        # (kein eigenständiges NOPASSWD für git, nur über safe-rebuild.sh)
      ];
    }
  ];
}
