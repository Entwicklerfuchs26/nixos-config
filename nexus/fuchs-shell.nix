{ config, pkgs, lib, ... }:

{
  users.users.fuchs-shell = {
    isSystemUser = true;
    group        = "fuchs-shell";
    home         = "/var/lib/fuchs-shell";
    createHome   = true;
  };
  users.groups.fuchs-shell = {};

  systemd.services.fuchs-shell = {
    description = "Fuchs – Shell MCP Server (Nexus)";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    environment = {
      HOME                 = "/var/lib/fuchs-shell";
      UV_PYTHON            = "${pkgs.python3}/bin/python3";
      UV_PYTHON_PREFERENCE = "only-system";
      UV_CACHE_DIR         = "/var/lib/fuchs-shell/.cache/uv";
      LD_LIBRARY_PATH = lib.makeLibraryPath [
        pkgs.stdenv.cc.cc.lib
        pkgs.zlib
        pkgs.openssl.out
        pkgs.glib
      ];
    };

    serviceConfig = {
      Type            = "simple";
      User            = "fuchs-shell";
      Group           = "fuchs-shell";
      EnvironmentFile = "/etc/sojus/fuchs-shell.env";
      ExecStart       = "${pkgs.uv}/bin/uv run --python ${pkgs.python3}/bin/python3 --with fastmcp --with httpx /etc/sojus/fuchs-shell-server.py";
      Restart         = "on-failure";
      RestartSec      = "15s";
      NoNewPrivileges = true;
      PrivateTmp      = false;
      # Shell-User braucht Lesezugriff auf Homeverzeichnis-Dateien von Jonas
      ReadOnlyPaths   = [ "/home/fuchs" ];
      ReadWritePaths  = [ "/var/lib/fuchs-shell" "/tmp" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 8012 ];
}
