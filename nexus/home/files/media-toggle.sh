#!/usr/bin/env bash
if eww active-windows 2>/dev/null | grep -q "media-picker"; then
  eww close media-picker
  hyprctl dispatch submap reset
else
  eww open media-picker
  hyprctl dispatch submap mediapicker
fi
