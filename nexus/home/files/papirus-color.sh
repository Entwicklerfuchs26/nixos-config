#!/usr/bin/env bash
source ~/.config/matugen/colors.sh

ACCENT="${MATUGEN_PRIMARY#\#}"

# Aktives Icon-Theme aus dconf
ICON_THEME=$(dconf read /org/gnome/desktop/interface/icon-theme 2>/dev/null | tr -d "'")
[ -z "$ICON_THEME" ] && ICON_THEME="Papirus-Dark"

ICON_DIR="$HOME/.local/share/icons/$ICON_THEME"
echo "Theme: $ICON_THEME | Akzent: #${ACCENT}"

python3 - "$ICON_DIR" "$ACCENT" <<'EOF'
import sys, os, re, colorsys, subprocess

icon_dir = sys.argv[1]
accent_hex = sys.argv[2]

def hex_to_hls(h):
    h = h.lstrip('#')
    r, g, b = int(h[0:2],16)/255, int(h[2:4],16)/255, int(h[4:6],16)/255
    return colorsys.rgb_to_hls(r, g, b)

def hls_to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return '#{:02x}{:02x}{:02x}'.format(int(r*255), int(g*255), int(b*255))

def recolor(old_hex, new_hue_hex):
    _, l, s = hex_to_hls(old_hex)
    new_h, _, _ = hex_to_hls(new_hue_hex)
    return hls_to_hex(new_h, l, s)

# Alle folder*.svg finden
folder_svgs = []
for root, dirs, files in os.walk(icon_dir):
    for f in files:
        if f.startswith('folder') and f.endswith('.svg'):
            folder_svgs.append(os.path.join(root, f))

if not folder_svgs:
    print(f"Keine Ordner-Icons in {icon_dir}")
    sys.exit(1)

# Farben aus ALLEN folder-SVGs sammeln (scalable hat die echten Farben)
old_colors = set()
for svg in folder_svgs:
    old_colors.update(re.findall(r'#[0-9a-fA-F]{6}', open(svg).read()))
# Grau/Weiß/Schwarz-Töne ignorieren (keine Akzentfarben)
old_colors = [c for c in old_colors if not all(
    abs(int(c[i:i+2],16) - int(c[j:j+2],16)) < 20
    for i,j in [(1,3),(1,5),(3,5)]
)]
color_map = {c: recolor(c, '#' + accent_hex) for c in old_colors}

print(f"Farben: {color_map}")

# Alle folder-SVGs umfärben
for svg_path in folder_svgs:
    content = open(svg_path).read()
    for old, new in color_map.items():
        content = content.replace(old, new)
    open(svg_path, 'w').write(content)

print(f"{len(folder_svgs)} Icons umgefärbt.")

# Icon-Cache aktualisieren
subprocess.run(['gtk-update-icon-cache', '-f', '-q', icon_dir],
               capture_output=True)
EOF
