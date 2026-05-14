#!/usr/bin/env bash
# Matugen Primärfarbe → nächste Papirus-Farbe

source ~/.config/matugen/colors.sh

HEX="${MATUGEN_PRIMARY#\#}"
R=$((16#${HEX:0:2}))
G=$((16#${HEX:2:2}))
B=$((16#${HEX:4:2}))

# RGB → Hue berechnen
MAX=$(( R > G ? (R > B ? R : B) : (G > B ? G : B) ))
MIN=$(( R < G ? (R < B ? R : B) : (G < B ? G : B) ))
DELTA=$(( MAX - MIN ))

if [ $DELTA -eq 0 ]; then
    HUE=0
elif [ $MAX -eq $R ]; then
    HUE=$(( (60 * (G - B) / DELTA + 360) % 360 ))
elif [ $MAX -eq $G ]; then
    HUE=$(( 60 * (B - R) / DELTA + 120 ))
else
    HUE=$(( 60 * (R - G) / DELTA + 240 ))
fi

# Hue → Papirus Farbe
if   [ $HUE -ge 0   ] && [ $HUE -lt 20  ]; then COLOR="red"
elif [ $HUE -ge 20  ] && [ $HUE -lt 40  ]; then COLOR="orange"
elif [ $HUE -ge 40  ] && [ $HUE -lt 65  ]; then COLOR="yellow"
elif [ $HUE -ge 65  ] && [ $HUE -lt 150 ]; then COLOR="green"
elif [ $HUE -ge 150 ] && [ $HUE -lt 185 ]; then COLOR="teal"
elif [ $HUE -ge 185 ] && [ $HUE -lt 220 ]; then COLOR="cyan"
elif [ $HUE -ge 220 ] && [ $HUE -lt 265 ]; then COLOR="blue"
elif [ $HUE -ge 265 ] && [ $HUE -lt 290 ]; then COLOR="violet"
elif [ $HUE -ge 290 ] && [ $HUE -lt 330 ]; then COLOR="magenta"
elif [ $HUE -ge 330 ] && [ $HUE -lt 345 ]; then COLOR="pink"
else COLOR="red"
fi

echo "Hue: $HUE → Papirus: $COLOR"
papirus-folders -C $COLOR --theme Papirus-Dark
