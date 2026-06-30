{ config, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;

    # Im Heimnetz erreichbar (Port 11434)
    host = "0.0.0.0";
    port = 11434;
    openFirewall = true;

    # Ressourcen-Begrenzung: 1 Modell im Speicher, 1 parallele Anfrage
    environmentVariables = {
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL      = "1";
      OLLAMA_FLASH_ATTENTION   = "1";
    };
  };
}
