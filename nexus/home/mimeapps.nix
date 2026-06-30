{ config, pkgs, ... }:
{

xdg.mimeApps = {
  enable = true;
  defaultApplications = {
    # Text & Code
    "text/plain"                  = "org.kde.kate.desktop";
    "text/x-shellscript"          = "org.kde.kate.desktop";
    "text/x-python"               = "org.kde.kate.desktop";
    "application/json"            = "org.kde.kate.desktop";
    "application/xml"             = "org.kde.kate.desktop";
    # PDF & Dokumente
    "application/pdf"             = "okularApplication_pdf.desktop";
    "application/epub+zip"        = "okularApplication_epub.desktop";
    # Bilder
    "image/png"                   = "org.kde.gwenview.desktop";
    "image/jpeg"                  = "org.kde.gwenview.desktop";
    "image/webp"                  = "org.kde.gwenview.desktop";
    "image/gif"                   = "org.kde.gwenview.desktop";
    "image/x-nikon-nef" = [ "org.kde.gwenview.desktop" "darktable.desktop" ];
    "image/x-raw"       = [ "org.kde.gwenview.desktop" "darktable.desktop" ];
    "image/tiff"                  = "org.kde.gwenview.desktop";
    # Krita
    "image/x-krita"               = "org.kde.krita.desktop";
    "image/x-xcf"                 = "org.kde.krita.desktop";
    # Blender
    "application/x-blender"       = "blender.desktop";
    # Video
    "video/mp4"                   = "vlc.desktop";
    "video/x-matroska"            = "vlc.desktop";
    "video/avi"                   = "vlc.desktop";
    "video/quicktime"             = "vlc.desktop";
    "video/webm"                  = "vlc.desktop";
  };
};

}
