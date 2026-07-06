{ pkgs }:

let
  python = pkgs.python3.withPackages (ps: [ ps.requests ]);
in
pkgs.writeShellScriptBin "AniO" ''
  exec ${python}/bin/python3 ${./anime-organizer.py} "$@"
''
