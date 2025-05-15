#!/bin/bash
# name		: swap-mgr-cli
# desciption	: manage swap files and partitions
# autor		: speefak (itoss@gmx.de)
# licence	: (CC) BY-NC-SA
# version	: 1.2

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

ScriptFile=$(readlink -f $(which $0))
ScriptName=$(basename $ScriptFile)
Version=$(grep -m1 "# version" "$ScriptFile" | awk -F ":" '{print $2}' | sed 's/ //g')
MailAddress="root"

DefaultSwapSize="15G"
DefaultSwapFile="/home/swap-extender"
DefaultSwapThresholdAlert=80

RequiredPackets="bash dialog"

TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

	OptionVarList="
		HelpDialog;-h
		ScriptInformation;-si
		CheckForRequiredPackages;-cfrp
		ShowSwaps;-s
		ShowSwapUsage;-u
		SwapThresholdAlert;-t
		ClearSwap;-c
		CreateSwapfile;-C
		ChooseAndDeleteSwapFile;-d
		Monochrome;-m
		ScriptInformation;-si
	"

	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
	for InputOption in $(echo " $@" | sed -e 's/-[a-z]/\n\0/g' ) ; do  				# | sed 's/ -/\n-/g'
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
			if [[ -n $(echo " $InputOption" | grep -w " $VarValue" 2>/dev/null) ]]; then 
				#InputOption=$(sed 's/[ 0]*$//'<<< $InputOption)
				InputOptionValue=$(awk -F "$OptionAllocator" '{print $2}' <<< "$InputOption" )
				if [[ -z $InputOptionValue ]]; then
					eval $(echo "$VarName"="true")
				else
					eval $(echo "$VarName"='$InputOptionValue')	
				fi
			fi
		done
	done
	IFS=$SAVEIFS

	# set default values
	SwapThresholdAlert=${SwapThresholdAlert/true/$DefaultSwapThresholdAlert}
	SwapFile=${CreateSwapfile/true/$DefaultSwapFile}

#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   fixed functions   ############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------
usage() {
	printf " swap-manager-cli: $Version | script location $basename $0\n"
	clear
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n"
	printf " -h			=> show help dialog \n"
	printf " -s			=> show swaps \n"
	printf " -u			=> show swap usage \n"
	printf " -t <1...100>		=> swap threshold alert (-t XX %%, default 80), send mail\n"
	printf " -c			=> clear swap \n"
	printf " -C <path/to/file>	=> create swapfile (default: $DefaultSwapFile-$DefaultSwapSize) \n"
	printf " -d			=> choose and delete swapfile (except swap partitions) \n"
	printf " -m			=> monochrome output \n"
	printf " -si			=> show script information \n"
	printf "\n"
	if [[ -z $1 ]]; then exit ; fi
	printf "$Red $1 $Reset\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------------------------------------------
script_information () {
	printf "\n"
	printf " Scriptname: $ScriptName\n"
	printf " Version:    $Version \n"
	printf " Scriptfile: $ScriptFile\n"
	printf " Filesize:   $(ls -lh $0 | cut -d " " -f5)\n"
	printf "\n"
	exit 0
}
#------------------------------------------------------------------------------------------------------------
load_color_codes () {
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'
	# Use them to print in your required colours:
	# printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."

	BG='\033[47m'
	FG='\033[0;30m'

	# reloard colored global vars
	for i in $(cat $0 | sed '/load_color_codes/q'  | grep '${Reset}'); do
		eval "$i"
	done
}
#------------------------------------------------------------------------------------------------------------------------------------------------
check_for_required_packages () {
	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf " missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) "			-i "Y" 		InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf " programm error: $LRed missing packets : $MissingPackets $Reset\n\n"$(tput sgr0)
			exit 1
		fi

	else
		printf "$LGreen all required packets detected$Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
show_swap_usage () {
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
#------------------------------------------------------------------------------------------------------------------------------------------------
swap_threshold_alert () {
	local threshold="$SwapThresholdAlert"
	local total used percent

	read -r total used <<< $(free | awk '/Swap:/ {print $2" "$3}')

	if [[ "$total" -eq 0 ]]; then
		echo "No swap space configured."
		exit 0
	fi

	# Check threshold value 0–100
	if ! [[ "$SwapThresholdAlert" =~ ^[0-9]+$ ]] || ! (( 0 <= 10#$SwapThresholdAlert && 10#$SwapThresholdAlert <= 100 )); then
		usage " invalid swap threshold value -t $SwapThresholdAlert"
	fi

	percent=$(( used * 100 / total ))

	if (( percent >= threshold )); then
		printf "$Red Swap usage is ${percent}%% which is above the threshold of ${threshold}%%.$Reset Sending mail to $MailAddress.\n\n"
		echo -e "Subject: Swap usage alert\n\nSwap usage is at ${percent}%." | sendmail "$MailAddress"
	else
		printf "$Green Swap usage is ${percent}%% which is under the threshold of ${threshold}%%.$Reset\n\n"
	fi

	exit 0
}
#------------------------------------------------------------------------------------------------------------------------------------------------
clear_swap () {
	echo "Clearing swap memory..."
	for Swap in $SwapActive; do
		swapoff "$Swap" && swapon "$Swap" && echo "Swap $Swap cleared"
	done
}
#------------------------------------------------------------------------------------------------------------------------------------------------
list_swaps() {
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
format_size() {
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
format_type() {
	local type="$1"
	printf "%-4s" "$type" | cut -c1-4
}
#------------------------------------------------------------------------------------------------------------------------------------------------
format_name() {
	local name="$1"
	printf "%-30s" "$name"
}
#------------------------------------------------------------------------------------------------------------------------------------------------
format_used() {
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
main_menu() {
	# disable menu when any option is entered
	if [[ ! $Interactive == true ]]; then return;fi

	local swaps_info
	IFS=$'\n' read -rd '' -a swaps_info <<< "$(list_swaps)"
	local menu_items=()

	for line in "${swaps_info[@]}"; do
		IFS='|' read -r name name_fmt size used type status <<< "$line"
		menu_items+=("$name" "Size: $size | Used: $used | Type: $type | Status: $status")
	done

	menu_items+=("Create a new swap file" " ")
	menu_items+=("Exit" " ")

	dialog --clear --title "Swap Management" \
		--menu "Select a swap file for further actions:" 20 100 10 \
		"${menu_items[@]}" 2>"$TMPFILE"

	local choice=$(<"$TMPFILE")

	if [[ "$choice" == "Create a new swap file" ]]; then
		create_swap
	elif [[ "$choice" == "Exit" ]]; then
		exit 0
	elif [[ -n "$choice" ]]; then
		swap_actions "$choice"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
swap_actions() {
	local swapfile="$1"
	dialog --clear --title "Action for $swapfile" \
		--menu "Choose an action:" 18 60 8 \
		1 "Activate / Clear swap (swapoff/swapon)" \
		2 "Deactivate swap" \
		3 "Deactivate and delete" \
		4 "Return to main menu" 2>"$TMPFILE"

	local action=$(<"$TMPFILE")

	case $action in
		1)
			sudo swapoff "$swapfile"
			sudo swapon "$swapfile"
			dialog --msgbox "$swapfile has been cleared (swapoff + swapon)." 6 50
			;;
		2)
			sudo swapoff "$swapfile"
			dialog --msgbox "$swapfile has been deactivated." 6 40
			;;
		3)
			sudo swapoff "$swapfile"
			sudo rm -f "$swapfile"
			sudo sed -i "\|$swapfile|d" /etc/fstab
			dialog --msgbox "$swapfile has been deactivated and deleted." 6 50
			;;
	esac

	main_menu
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_swap() {
	dialog --inputbox "Size of the new swap file in M (mb) or G (gb):" 8 60 $DefaultSwapSize 2>"$TMPFILE"
	local size=$(<"$TMPFILE")

	dialog --inputbox "Path for the new swap file:" 8 60 "$DefaultSwapFile-$size" 2>"$TMPFILE"
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

	if [[ -z $CreateSwapfile ]]; then main_menu;fi

}
#------------------------------------------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------------------------------------------

	# check for cronjob execution and cronjob options
	CronExecution=
	if [ -z $(grep "/" <<< "$(tty)") ]; then
		CronExecution=true
		Monochrome=true
		TERM=xterm-256color
# 		TERM=linux
		export TERM 
	fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# check for help dialog
	if [[ -n $HelpDialog ]]; then usage ;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $ScriptInformation ]]; then script_information ;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	if [[ -z $Monochrome ]]; then	load_color_codes ;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# check for root permission
	if [[ "$(whoami)" = "root" ]]; then echo "";else echo "Are You Root ?";exit 1;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# show swaps
	if [[ -n $ShowSwaps ]]; then swapon --show;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# show swap usage 
	if [[ -n $ShowSwapUsage ]]; then show_swap_usage;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# check swap_threshold_alert
	if [[ -n $SwapThresholdAlert ]]; then swap_threshold_alert;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# clear swap
	if [[ -n $ClearSwap ]]; then clear_swap;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# create swap file
	if [[ -n $CreateSwapfile ]]; then create_swap;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# show swap usage 
	if [[ -n $ChooseAndDeleteSwapFile ]]; then choose_and_delete_swap;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# selection dailog
	if [[ -z "$1"  ]]; then
		Interactive=true
		main_menu
	fi

#------------------------------------------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------------------------------------------------------------------

# TODO Warning when deleting swap partitions

# TODO reconfigure main swap partition () {
rm -f /dev/mapper/D12--System-Swap
dmsetup mknodes
udevadm trigger
mkswap /dev/mapper/D12--System-Swap
swapon /dev/mapper/D12--System-Swap
}
