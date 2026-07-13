{ config, pkgs, ... }:

{
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

  # ── Sudoers-Whitelist für sojus ───────────────────────────────────────────────
  # Nur diese Befehle sind erlaubt – alles andere ist DENY by default.
  # Explizit NICHT erlaubt (nicht gelistet): dd, mkfs, parted, userdel,
  #   passwd (für andere User), rm -rf auf Systempfade, shutdown, poweroff.
  security.sudo.extraRules = [
    {
      users = [ "sojus" ];
      commands = [
        # systemctl: nur restart/status für Sojus-relevante Services
        {
          command = "/run/current-system/sw/bin/systemctl restart sojus-core";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status sojus-core";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart fuchs-shell";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl status fuchs-shell";
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

        # Wrapper-Skript (einziger erlaubter Rebuild-Einstiegspunkt)
        {
          command = "/home/sojus/bin/safe-rebuild.sh";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/home/sojus/bin/safe-rebuild.sh *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
