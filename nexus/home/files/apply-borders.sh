#!/usr/bin/env bash
source ~/.config/matugen/colors.sh
hyprctl keyword general:col.active_border "rgba(${MATUGEN_PRIMARY#\#}ff)"
hyprctl keyword general:col.inactive_border "rgba(${MATUGEN_SURFACE#\#}ff)"
hyprctl keyword decoration:shadow:color "rgba(${MATUGEN_PRIMARY#\#}44)"
