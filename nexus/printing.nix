{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.epson-escpr2 ];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
