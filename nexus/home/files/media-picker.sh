#!/usr/bin/env bash
# VPN verbinden, dann Aniworld öffnen
if ! nmcli -t -f TYPE,STATE connection show --active 2>/dev/null | grep -q "^vpn:activated"; then
  VPN=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ":vpn" | head -1 | cut -d: -f1)
  if [[ -n "$VPN" ]]; then
    notify-send "Media" "VPN: $VPN wird verbunden…" -t 3000
    nmcli con up "$VPN" 2>/dev/null
    for i in $(seq 1 10); do
      nmcli -t -f TYPE,STATE connection show --active 2>/dev/null | grep -q "^vpn:activated" && break
      sleep 1
    done
  else
    notify-send "Media" "Kein VPN konfiguriert – ohne VPN geöffnet" -t 5000
  fi
fi
vivaldi --app="https://aniworld.to" --class=media-aniworld &
