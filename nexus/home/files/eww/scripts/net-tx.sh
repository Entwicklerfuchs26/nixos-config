#!/usr/bin/env bash
prev=0
while true; do
    curr=$(awk '/enp5s0:/ {print $10}' /proc/net/dev)
    if [ "$prev" -ne 0 ] && [ -n "$curr" ]; then
        echo $(( (curr - prev) / 2 / 1024 ))
    fi
    prev=$curr
    sleep 2
done
