{ config, lib, pkgs, ... }:

{
  # Resolve ist unfree – global vermutlich schon aktiv (NVIDIA läuft ja).
  # Falls nicht, reicht diese gezielte Freigabe:
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "davinci-resolve" ];

  environment.systemPackages = with pkgs; [
    davinci-resolve
    ffmpeg
    mediainfo

    (pkgs.writeShellApplication {
    name = "convert-to-dnxhr";
    runtimeInputs = [ pkgs.ffmpeg ];
    text = ''
      shopt -s nullglob nocaseglob
      files=( *.mp4 *.mkv )

      if [ ''${#files[@]} -eq 0 ]; then
        echo "Keine .mp4/.mkv-Dateien im aktuellen Ordner gefunden."
        exit 1
      fi

      mkdir -p dnxhr

      converted=0
      skipped=0

      for f in "''${files[@]}"; do
        out="dnxhr/''${f%.*}.mov"

        if [ -f "$out" ]; then
          echo "-- Überspringe (existiert bereits): $out"
          skipped=$(( skipped + 1 ))
          continue
        fi

        echo ">> Konvertiere: $f  ->  $out"
        ffmpeg -hide_banner -loglevel warning -stats -i "$f" \
          -c:v dnxhd -profile:v dnxhr_lb -pix_fmt yuv422p \
          -c:a pcm_s16le \
          "$out"
      converted=$(( converted + 1 ))
      done

      echo "Fertig: $converted konvertiert, $skipped übersprungen."
    '';
  })
  ];
}
