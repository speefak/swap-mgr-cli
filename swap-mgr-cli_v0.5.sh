#!/bin/bash

EMAIL="root@localhost"
THRESHOLD=80  # Schwellenwert für E-Mail-Benachrichtigung

show_swap_usage() {
    grep Swap /proc/*/smaps 2>/dev/null | 
    awk '{proc[$1]+=$2} END {for (p in proc) print p, proc[p]}' | 
    sort -k2 -nr | 
    while read pid swap; do 
        ps -p $(echo $pid | grep -oP '[0-9]+') -o pid,user,comm,%mem,%cpu --no-headers 2>/dev/null | 
        awk -v sw="$swap" '{
            if (sw >= 1024*1024) 
                size=sprintf("%.2f GB", sw/1024/1024); 
            else if (sw >= 1024) 
                size=sprintf("%.2f MB", sw/1024); 
            else 
                size=sprintf("%d kB", sw); 
            print $0, size;
        }'; 
    done | column -t
}

clear_swap() {
    echo "Leere Swap-Speicher..."
    for swap in $(swapon --show=NAME --noheadings); do
        swapoff "$swap" && swapon "$swap" && echo "Swap $swap geleert"
    done
}

monitor_swap() {
    usage=$(free | awk '/Swap:/ {print ($3/$2)*100}')
    usage=${usage%.*}  # Ganze Zahl extrahieren
    if [ "$usage" -ge "$THRESHOLD" ]; then
        echo "WARNUNG: Swap-Nutzung bei ${usage}%!" | mail -s "Swap-Warnung" "$EMAIL"
    fi
}

case "$1" in
    -l) show_swap_usage ;;
    -c) clear_swap ;;
    -m) monitor_swap ;;
    *) echo "Nutzung: $0 -l (swap load) | -c (clear swap) | -m (monitor swap)" ;;
esac
