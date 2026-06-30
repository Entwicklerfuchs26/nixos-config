#!/usr/bin/env bash
while true; do
    read _ u n s i iw irq si st _ _ < /proc/stat
    sleep 2
    read _ u2 n2 s2 i2 iw2 irq2 si2 st2 _ _ < /proc/stat
    total=$(( (u2+n2+s2+i2+iw2+irq2+si2+st2) - (u+n+s+i+iw+irq+si+st) ))
    idle=$(( i2 + iw2 - i - iw ))
    [[ $total -gt 0 ]] && echo $(( 100 * (total - idle) / total )) || echo 0
done
