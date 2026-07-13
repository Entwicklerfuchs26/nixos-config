{ config, pkgs, lib, ... }:

{
  # ── agenix Secret: SHELL_MCP_API_KEY ─────────────────────────────────────────
  age.secrets.fuchs-shell-env = {
    file   = ../secrets/fuchs-shell-env.age;
    owner  = "fuchs-shell";
    group  = "fuchs-shell";
    mode   = "0400";
  };

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
      # EnvironmentFile kommt jetzt von agenix (wird bei jedem Boot aus .age entschlüsselt)
      EnvironmentFile = config.age.secrets.fuchs-shell-env.path;
      ExecStart       = "${pkgs.uv}/bin/uv run --python ${pkgs.python3}/bin/python3 --with fastmcp --with httpx /etc/sojus/fuchs-shell-server.py";
      Restart         = "on-failure";
      RestartSec      = "15s";
      NoNewPrivileges = true;
      PrivateTmp      = false;
      ReadOnlyPaths   = [ "/home/fuchs" ];
      ReadWritePaths  = [ "/var/lib/fuchs-shell" "/tmp" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 8012 ];
}
