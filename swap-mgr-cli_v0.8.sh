#!/bin/bash
# name          : backup_website.sh
# desciption    : website backupscript for database and website content
# autor         : speefak (itoss@gmx.de)
# licence       : (CC) BY-NC-SA
# version	: 8.0

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
 DefaultSwapFile="/home/swap-extender"

 SwapAll="$( { swapon --noheadings --raw | awk '{print $1}'; awk '$2 == "swap" {print $1}' /etc/fstab; } | sort -u )"
 SwapActive=$(swapon --show=NAME --noheadings)
 DefaultSwapThresholdAlert=80

 RequiredPackets="bash dialog"

# RAMDISK_MOUNT="/mnt/ramdisk"

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

	# check for correct threshold input (1-100)
	if ! [[ "$SwapThresholdAlert" =~ ^[0-9]+$ ]] || (( SwapThresholdAlert < 1 || SwapThresholdAlert > 100 )); then
		usage "Invalid swap threshold alert value: $SwapThresholdAlert"
	fi

	usage=$(free | awk '/Swap:/ {print ($3/$2)*100}')
	usage=${usage%.*}  # Ganze Zahl extrahieren
	if [ "$usage" -ge "$SwapThresholdAlert" ]; then
		printf "$Red WARNING: Swap usage for $(hostname) at ${usage}%% $Reset\n\n"
		echo " WARNING: Swap usage for $(hostname) at ${usage}%" | mail -s "Swap Warning from $(hostname)" "$MailAddress"
	else
		printf "$Green swap usage for $(hostname) at ${usage}%%$Reset, threshold not reached ($SwapThresholdAlert%%) \n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
clear_swap () {
	echo "Clearing swap memory..."
	for Swap in $SwapActive; do
		swapoff "$Swap" && swapon "$Swap" && echo "Swap $Swap cleared"
	done
}
#------------------------------------------------------------------------------------------------------------------------------------------------
create_swapfile () {

	read -e -p " enter swap file size:      " -i "$DefaultSwapSize" Swapsize
	Swapsize=${Swapsize:-$DefaultSwapSize}

	read -e -p " enter swap file location:  " -i "$SwapFile-$Swapsize" Swapfile
	Swapfile=${Swapfile:-$DefaultSwapFile}

	# check for active swapfile
	request_swap_file () {
		for i in $SwapActive ; do
			if [[ $i == "$Swapfile" ]]; then
				printf " swapfile allready active:  $i \n"
				read -e -p " reload or create new (r|n): " -i "r" CreateSwapfile
					if [[ ! $CreateSwapfile == [rRnN] ]]; then
						request_swap_file
					fi
			else
				i="$Swapfile"
				CreateSwapfile=n
			fi
		done

	}
	request_swap_file

	printf "\033[1A\033[2K"
	if [[ $CreateSwapfile == [rR] ]]; then
		printf " reload swapfile:           $i \n"
		swapoff $i
		swapon $i
		return
	elif [[ $CreateSwapfile == [nN] ]]; then
		for i in $SwapActive ; do
			if [[ $i == "$Swapfile" ]]; then
				Swapfile="$Swapfile-1"
			fi
		done
	fi

	printf " create swap file:          "$Swapfile" | size $Swapsize...\n"
	fallocate -l "$Swapsize" "$Swapfile"
	chmod 600 "$Swapfile"
	mkswap "$Swapfile"
	swapon "$Swapfile"
	printf "\n active swaps on $(hostname):\n"
	swapon

	 # Eintrag in /etc/fstab nur vornehmen, wenn nicht bereits vorhanden
	if ! grep -q "[[:space:]]$Swapfile[[:space:]]" /etc/fstab; then
		SwapUUID=$(blkid -o value -s UUID "$Swapfile" 2>/dev/null)
	if [[ -z "$SwapUUID" ]]; then
		echo "$Swapfile none swap sw,nofail 0 0" >> /etc/fstab
	else
		echo "UUID=$SwapUUID none swap sw,nofail 0 0" >> /etc/fstab
	fi
		echo "$Green Swapfile in /etc/fstab eingetragen. $Reset"
	else
		echo "$Yellow Swapfile ist bereits in /etc/fstab eingetragen.$Reset"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
choose_and_delete_swap() {

	# Alle aktiven Swaps holen (außer Header)
	mapfile -t swaps < <(swapon --noheadings --raw | awk '{print $1}' | grep -v "^/dev/")

	if [ ${#swaps[@]} -eq 0 ]; then
		printf "$Yellow Keine aktiven Swap-Dateien gefunden.$Reset\n"
		swapon
		return 0
	fi

	# Temporäre Datei für dialog-Ausgabe
	tmpfile=$(mktemp)

	# Liste für dialog vorbereiten (id + pfad)
	options=()
	for i in "${!swaps[@]}"; do
		options+=("$i" "${swaps[$i]}")
	done

	# dialog-Menü anzeigen
	dialog --clear --title "Swap auswählen" \
		--menu "Wähle einen Swap zum Deaktivieren und Löschen:" 15 70 6 \
		"${options[@]}" 2>"$tmpfile"

	retval=$?
	choice=$(<"$tmpfile")
	rm -f "$tmpfile"

	# Abbruch oder keine Auswahl
	if [ $retval -ne 0 ] || [ -z "$choice" ]; then
		echo "Abgebrochen."
		return 1
	fi

	swap_to_remove="${swaps[$choice]}"

	echo "Deaktiviere Swap: $swap_to_remove"
	swapoff "$swap_to_remove" || {
	echo "Fehler beim Deaktivieren von $swap_to_remove"
	return 1
	}

	# Nur löschen, wenn es sich um eine Datei handelt (nicht z.B. Partition)
	if [[ "$swap_to_remove" == /* && -f "$swap_to_remove" ]]; then
		rm -f "$swap_to_remove" && printf "$Green Swap-Datei gelöscht: $swap_to_remove $Reset"
		 # Entferne den Eintrag aus /etc/fstab
		sed -i "\|[[:space:]]$Swapfile[[:space:]]|d" /etc/fstab
		printf "$Green Swap-Datei Eintrag aus /etc/fstab entfernt: $Swapfile $Reset"
		break
	else
		printf "$Yellow Hinweis: $swap_to_remove ist keine reguläre Datei, wird nicht gelöscht.\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
#create_ramdisk() {
#    read -p "Enter RAM disk size (e.g., 1G): " size
#    [ -z "$size" ] && { echo "Size is required"; return; }
#    
#    echo "Creating RAM disk of size $size at $RAMDISK_MOUNT..."
#    mkdir -p "$RAMDISK_MOUNT"
#    mount -t tmpfs -o size="$size" tmpfs "$RAMDISK_MOUNT" && echo "RAM disk mounted at $RAMDISK_MOUNT"
#}
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
	if [[ -z $1 ]] || [[ -n $HelpDialog ]]; then usage ;fi

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
	if [[ -n $CreateSwapfile ]]; then create_swapfile;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

	# show swap usage 
	if [[ -n $ChooseAndDeleteSwapFile ]]; then choose_and_delete_swap;fi

#------------------------------------------------------------------------------------------------------------------------------------------------

exit 0




# notice
# https://wiki.ubuntuusers.de/Swap/ => sudo sysctl vm.swappiness=10

