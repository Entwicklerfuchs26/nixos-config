{ config, pkgs, ... }:
{
  home.file.".config/eww/eww.yuck" = { source = ./files/eww/eww.yuck; force = true; };
  home.file.".config/eww/scripts/net-rx.sh" = {
    source = ./files/eww/scripts/net-rx.sh;
    executable = true;
  };
  home.file.".config/eww/scripts/net-tx.sh" = {
    source = ./files/eww/scripts/net-tx.sh;
    executable = true;
  };
  home.file.".config/eww/scripts/cpu.sh" = {
    source = ./files/eww/scripts/cpu.sh;
    executable = true;
  };

  home.file.".local/bin/AniDL" = {
    source = ./files/anidl.sh;
    executable = true;
  };

  home.file.".local/bin/media-picker" = {
    source = ./files/media-picker.sh;
    executable = true;
  };

  home.file.".local/bin/media-toggle" = {
    source = ./files/media-toggle.sh;
    executable = true;
  };

  home.file.".local/bin/ambient-toggle" = {
    source = ./files/ambient-toggle.sh;
    executable = true;
  };

  home.file.".local/bin/ambient-waybar" = {
    source = ./files/ambient-waybar.sh;
    executable = true;
  };

  home.file.".local/bin/bt-menu" = {
    source = ./files/bt-menu.sh;
    executable = true;
  };

  home.file.".local/bin/net-menu" = {
    source = ./files/net-menu.sh;
    executable = true;
  };

  home.file.".local/bin/ambient-daemon" = {
    source = ./files/ambient-daemon.py;
    executable = true;
  };

  home.file.".config/wlogout/style.css.templ".source = ./files/wlogout-style.css.templ;
  home.file.".config/nwg-dock-hyprland/style.css.templ".source = ./files/nwg-dock-style.css.templ;
  home.file.".config/nwg-dock-hyprland/pinned" = {
    source = ./files/nwg-dock-pinned;
    force = true;
  };
  home.file.".config/OpenRGB/OpenRGB.json".source = ./files/OpenRGB.json;
  home.file.".config/gtk-3.0/settings.ini".source = ./files/gtk3-settings.ini;
  home.file.".config/gtk-4.0/settings.ini".source = ./files/gtk4-settings.ini;
  home.file.".icons/default/index.theme".source = ./files/cursor-index.theme;
  home.file.".config/qt5ct/qt5ct.conf".source = ./files/qt5ct.conf;

  systemd.user.services.ambient-daemon = {
    Unit = {
      Description = "Hyperion Ambient Light Daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "%h/.local/bin/ambient-daemon";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = "PATH=/run/current-system/sw/bin:/run/wrappers/bin:/home/fuchs/.local/bin";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
