#!/bin/bash

EMAIL="root@localhost"
THRESHOLD=80  # Schwellenwert für E-Mail-Benachrichtigung
DEFAULT_SWAPFILE="/home/swap-extend.swp"
DEFAULT_SWAPSIZE=10G
RAMDISK_MOUNT="/mnt/ramdisk"

show_swap_usage() {
    echo "Reading swap usage..."
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
    echo "Clearing swap memory..."
    for swap in $(swapon --show=NAME --noheadings); do
        swapoff "$swap" && swapon "$swap" && echo "Swap $swap cleared"
    done
}

monitor_swap() {
    usage=$(free | awk '/Swap:/ {print ($3/$2)*100}')
    usage=${usage%.*}  # Ganze Zahl extrahieren
    if [ "$usage" -ge "$THRESHOLD" ]; then
        echo "WARNING: Swap usage at ${usage}%!" | mail -s "Swap Warning" "$EMAIL"
    fi
}

create_ramdisk() {
    read -p "Enter RAM disk size (e.g., 1G): " size
    [ -z "$size" ] && { echo "Size is required"; return; }
    
    echo "Creating RAM disk of size $size at $RAMDISK_MOUNT..."
    mkdir -p "$RAMDISK_MOUNT"
    mount -t tmpfs -o size="$size" tmpfs "$RAMDISK_MOUNT" && echo "RAM disk mounted at $RAMDISK_MOUNT"
}

create_swapfile() {
    read -p "Enter swap file location (default: $DEFAULT_SWAPFILE): " swapfile
    swapfile=${swapfile:-$DEFAULT_SWAPFILE}

    read -p "Enter swap file size (default: $DEFAULT_SWAPSIZE): " swapsize
    swapsize=${swapsize:-$DEFAULT_SWAPSIZE}

    echo "Creating swap file at $swapfile with size $swapsize..."
    fallocate -l "$swapsize" "$swapfile" || dd if=/dev/zero of="$swapfile" bs=1M count=$(echo "$swapsize" | sed 's/G//')000
    chmod 600 "$swapfile"
    mkswap "$swapfile"
    swapon "$swapfile" && echo "Swap file $swapfile activated"
}

case "$1" in
    -l) show_swap_usage ;;
    -c) clear_swap ;;
    -m) monitor_swap ;;
    -r) create_ramdisk ;;
    -s) create_swapfile ;;
    *) echo "Usage: $0 -l (show swap) | -c (clear swap) | -m (monitor swap) | -r (create RAM disk) | -s (create swap file)" ;;
esac

