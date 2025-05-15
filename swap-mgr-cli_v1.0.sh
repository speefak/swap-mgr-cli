#!/bin/bash
# name          : backup_website.sh
# desciption    : website backupscript for database and website content
# autor         : speefak (itoss@gmx.de)
# licence       : (CC) BY-NC-SA
# version	: 1.1

#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)
 Version=$(grep -m1 "# version" "$ScriptFile" | awk -F ":" '{print $2}' | sed 's/ //g')
 MailAddress="root"
 
 DefaultSwapSize="15G"
 DefaultSwapFile="/home/swap-extender-$DefaultSwapSize"
 DefaultSwapThresholdAlert=80

 RequiredPackets="bash dialog"

#------------------------------------------------------------------------------------------------------------------------------------------------

 TMPFILE=$(mktemp)
 trap "rm -f $TMPFILE" EXIT

#------------------------------------------------------------------------------------------------------------------------------------------------
# Lists all swap entries: active and from /etc/fstab
function list_swaps() {
    local active_swaps fstab_swaps all_swaps

    mapfile -t active_swaps < <(swapon --show=NAME,SIZE,USED,TYPE --noheadings | grep '^/')
    mapfile -t fstab_swaps < <(grep -v '^#' /etc/fstab | awk '$3=="swap" {print $1}')

    declare -A already_listed

    for line in "${active_swaps[@]}"; do
        local name size used type
        name=$(echo "$line" | awk '{print $1}')
        size=$(format_size $(echo "$line" | awk '{print $2}'))
        used=$(format_used $(echo "$line" | awk '{print $3}'))
        type=$(format_type $(echo "$line" | awk '{print $4}'))
        name_fmt=$(format_name "$name")
        echo "$name|$name_fmt|$size|$used|$type|ACTIVE"
        already_listed["$name"]=1
    done

    for fstab_entry in "${fstab_swaps[@]}"; do
        if [[ -z "${already_listed[$fstab_entry]}" ]]; then
            name="$fstab_entry"
            size=" -----"
            used=" -----"
            type="----"
            name_fmt=$(format_name "$name")
            echo "$name|$name_fmt|$size|$used|$type|INACTIVE"
        fi
    done
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function format_size() {
    local raw_size="$1"
    if [[ "$raw_size" =~ ^([0-9]+\.[0-9])G$ ]]; then
        printf "%6s" "$raw_size"
    elif [[ "$raw_size" =~ ^([0-9]+)G$ ]]; then
        printf "%6s" "${BASH_REMATCH[1]}.0G"
    else
        printf "%6s" "$raw_size"
    fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function format_type() {
    local type="$1"
    printf "%-4s" "$type" | cut -c1-4
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function format_name() {
    local name="$1"
    printf "%-30s" "$name"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function format_used() {
    local raw_used="$1"
    if [[ "$raw_used" =~ ^([0-9]+\.[0-9])G$ ]]; then
        printf "%6s" "$raw_used"
    elif [[ "$raw_used" =~ ^([0-9]+)G$ ]]; then
        printf "%6s" "${BASH_REMATCH[1]}.0G"
    else
        printf "%6s" "$raw_used"
    fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function main_menu() {
    local swaps_info
    IFS=$'\n' read -rd '' -a swaps_info <<< "$(list_swaps)"
    local menu_items=()

    for line in "${swaps_info[@]}"; do
        IFS='|' read -r name name_fmt size used type status <<< "$line"
        menu_items+=("$name" "Size: $size | Used: $used | Type: $type | Status: $status")
    done

    menu_items+=("Create new swap file" " ")

    dialog --clear --title "Swap Management" \
        --menu "Select a swap file for further actions:" 20 100 10 \
        "${menu_items[@]}" 2>"$TMPFILE"

    local choice=$(<"$TMPFILE")

    if [[ "$choice" == "NEW" ]]; then
        create_swap
    elif [[ -n "$choice" ]]; then
        swap_actions "$choice"
    fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function swap_actions() {
    local swapfile="$1"
    dialog --clear --title "Action for $swapfile" \
        --menu "Choose an action:" 15 60 5 \
        1 "Clear swap (swapoff/swapon)" \
        2 "Deactivate and delete" \
        3 "Return to main menu" 2>"$TMPFILE"

    local action=$(<"$TMPFILE")

    case $action in
        1)
            sudo swapoff "$swapfile"
            sudo swapon "$swapfile"
            dialog --msgbox "Swap was cleared." 6 40
            ;;
        2)
            sudo swapoff "$swapfile"
            sudo rm -f "$swapfile"
            sudo sed -i "\|$swapfile|d" /etc/fstab
            dialog --msgbox "$swapfile was deactivated and deleted." 6 50
            ;;
    esac

    main_menu
}
#------------------------------------------------------------------------------------------------------------------------------------------------
function create_swap() {
    dialog --inputbox "Size of the new swap file in M (mb) or G (gb):" 8 60 $DefaultSwapSize 2>"$TMPFILE"
    local size=$(<"$TMPFILE")

    dialog --inputbox "Path for the new swap file:" 8 60 "$DefaultSwapFile" 2>"$TMPFILE"
    local path=$(<"$TMPFILE")

    if [[ -z "$size" || -z "$path" ]]; then
        dialog --msgbox "Invalid input. No swap created." 6 50
        main_menu
        return
    fi

    if [[ -e "$path" ]]; then
        dialog --msgbox "File $path already exists." 6 50
        main_menu
        return
    fi

    if grep -q "^$path" /etc/fstab; then
        dialog --msgbox "$path is already listed in /etc/fstab." 6 50
        main_menu
        return
    fi

    if swapon --show=NAME --noheadings | grep -q "^$path$"; then
        dialog --msgbox "$path is already in use as swap." 6 50
        main_menu
        return
    fi

    sudo fallocate -l ${size} "$path" || sudo dd if=/dev/zero of="$path" bs=1M count="$size"
    sudo chmod 600 "$path"
    sudo mkswap "$path"
    sudo swapon "$path"
    echo "$path none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
    dialog --msgbox "Swap file created and activated." 6 50

    main_menu
}
#------------------------------------------------------------------------------------------------------------------------------------------------

	main_menu

#------------------------------------------------------------------------------------------------------------------------------------------------

exit 0

