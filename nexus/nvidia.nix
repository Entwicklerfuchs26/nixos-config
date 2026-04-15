{ config, pkgs, ... }:

{
  # NVIDIA Treiber aktivieren
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Stabiler proprietärer Treiber
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Wayland mit NVIDIA sauber konfigurieren
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Umgebungsvariablen für NVIDIA und Wayland
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
