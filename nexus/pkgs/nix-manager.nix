{ pkgs }:

let
  pythonWithDeps = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);

  wrapScript = pkgs.writeScript "nix-manager-run" ''
    #!/bin/sh
    exec ${pythonWithDeps}/bin/python3 ${./nix-manager.py} "$@"
  '';
in pkgs.stdenv.mkDerivation {
  pname = "nix-manager";
  version = "0.1.0";
  dontUnpack = true;

  nativeBuildInputs = with pkgs; [
    wrapGAppsHook4
    gobject-introspection
  ];

  buildInputs = with pkgs; [
    gtk4
    libadwaita
    glib
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications

    cp ${wrapScript} $out/bin/nix-manager
    chmod +x $out/bin/nix-manager

    cat > $out/share/applications/nix-manager.desktop << 'DESK'
    [Desktop Entry]
    Name=Nix Manager
    Comment=NixOS Pakete verwalten
    Exec=nix-manager
    Icon=package-x-generic
    Type=Application
    Categories=System;Settings;
    DESK

    runHook postInstall
  '';
}
