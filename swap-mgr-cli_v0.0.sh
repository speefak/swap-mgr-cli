#!/bin/bash
# name          : swap-mgr_cli.sh
# desciption    : manage and monitor swap file
# autor         : speefak ( itoss@gmx.de )
# licence       : (CC) BY-NC-SA
# version 	: 0.0
# notice 	: 
# infosource	: 
#		  
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 RequiredPackets="bash sed awk"

 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)
 Version=$(cat $ScriptFile | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')

 UsageCheckIntervall=10
 HParser="numfmt --to iec --round=nearest"								# convert to human readable vars TODO => user floating vars x.xx

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################   define global variables root permission required  ############################
############################################################################################################

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	OptionVarList="

		HelpDialog;-h
		Monochrome;-m
		ScriptInformation;-si
		CheckForRequiredPackages;-cfrp
		ShowSwapInfo;-ssi
		CreateSwapFile;-csf
		CreateRamDisk;-crd
		ThresholdWarning;-tw
		ClearSwap;-cs
		MailLogReport;-ml
	"

	# set entered vars from optionvarlist
	OptionAllocator="="										# for option seperator "=" use cut -d "="
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

	# set default vars
	 Backupuser=${BackupUser:-$(getent passwd | grep 1000 | cut -d ":" -f1)}

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
load_color_codes () {
	# parse required colours for echo/printf usage: printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'

	BG='\033[47m'
	FG='\033[0;30m'

	# sed parser '\033[1;31m' => '\\033[1;31m'
	if [[ $1 == sed ]]; then
		eval $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='" | sed 's|\\|\\\\|g')
	fi

	# unset color codes
	if [[ $1 == "-u" ]]; then
		eval $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='" | sed 's/=.*/=/')
	fi
}
#------------------------------------------------------------------------------------------------------------
usage() {
	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n"
	printf " -h		=> help dialog \n"
	printf " -m		=> monochrome output \n"
	printf " -si		=> show script information \n"
	printf " -cfrp		=> check for required packets \n"
	printf "\n"
	printf " -ssi		=> show swap info \n"
	printf " -csf=<x;y>	=> create swap file ( x= size (mb/gb) ; y = path/to/file ) \n"	
	printf " -crd=<x>	=> create ram disk ( x = mb/gb ) \n"
	printf " -tw		=> threshold warning ( send mail when threshold reached )\n"
	printf " -cs		=> clear swap (swap off/on) \n"
	printf " -ml		=> mail log report ( mail reports)  \n"

	printf  "\n${LRed} $1 ${Reset}\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------
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
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
   		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) "		 	-i "Y" 		InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: $LRed missing packets : $MissingPackets $Reset\n\n"$(tput sgr0)
			exit 1
		fi

	else
		printf "$LGreen all required packets detected$Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------------------------------------------
progressbar () {   									# usage : progressbar  "MESSAGE" 3 "."
	echo -ne "$1     "
	for i in `seq 1 $2`; do
		echo -en "\033[K$3"
		sleep 1
	done
	echo -en "\015"
}
#------------------------------------------------------------------------------------------------------------
countdown_request () {
	RequestCountdown=10
	CountdownRequestMessage="proceed ?"
	tput civis 
	for i in $(seq 1 $RequestCountdown) ;do
		read -t1 -n1 -s -p "$CountdownRequestMessage (y/n) " Request
		request () {
			if   [[ "$Request" == "[yY]" ]]; then
				DeleteUserConfigs=true
				break	
			elif [[ "$Request" == "[nN]" ]]; then
				DeleteUserConfigs=false
				break
			elif   [[ -n "$Request" ]] ;then 
				request	
			fi
			DeleteUserConfigs=true
			printf '%2s\r' $(echo $(($RequestCountdown-$i)))
		}
		request
	done
	printf '%50s\r'
	tput cnorm
}
#------------------------------------------------------------------------------------------------------------
countdown_default () {
	tput civis 
	CountdownTimer=20
	CountdownMessage="Kill and restart in: (press any key to abort) "
	for i in $(seq 1 $CountdownTimer) ;do
		read -t1 -n1 -s -p "$CountdownMessage" Request1 
			if   [[ -n "$Request1" ]] ;then
				printf "\nContinue running instance.\n"
				printf "Exit ...\n"
				tput cnorm
				exit 						
			fi
			printf '%2s\r' $(echo $(($CountdownTimer-$i)))
	done
	printf '%50s\r'
	tput cnorm 
}
#------------------------------------------------------------------------------------------------------------
get_swap_info () {

	# get swap parameter

	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")

	for SwapLocation in $(cat /proc/swaps | sed '1d') ; do				# SwapLocation=$(cat /proc/swaps | sed '1d')

		SwapPath=$( awk '{print $1}'<<< $SwapLocation)
		SwapType=$( awk '{print $2}'<<< $SwapLocation)
		SwapSize=$( awk '{print $3}'<<< $SwapLocation)
		SwapUsed=$( awk '{print $4}'<<< $SwapLocation)
		SwapFree=$(($SwapSize - $SwapUsed))
		SwapUsedPercent=$(($SwapUsed * 100 / $SwapSize))
		SwapFreePercent=$((100-$SwapUsedPercent))

	done

	IFS=$SAVEIFS

}
#------------------------------------------------------------------------------------------------------------
show_swap_info () {											# TODO show floating vars 

		HParser="numfmt --to iec --round=nearest"

		# printf swap information
		printf " swap location:	$SwapPath ($SwapType) \n"
#		printf " swap size:	$($HParser <<< $(($SwapSize*1024)))\n"
		printf " swap info:	$SwapUsedPercent %% ($($HParser <<< $(($SwapUsed*1024))) of $($HParser <<< $(($SwapSize*1024)))) \n"
		printf "\n\n"
}
#------------------------------------------------------------------------------------------------------------
create_swap_file () {
echo
}
#------------------------------------------------------------------------------------------------------------
create_ram_disk() {
echo
}
#------------------------------------------------------------------------------------------------------------
usage_warning() {
echo
}
#------------------------------------------------------------------------------------------------------------
clear_swap() {
echo
}
#------------------------------------------------------------------------------------------------------------
mail_log_report () {
echo
}
#------------------------------------------------------------------------------------------------------------
clear_swap () {


	# check for free RAM 
#	if [[ $FreeRam -lt $SwapUsed ]]; then
#		echo not eoungt free RAM to clear swap
#	fi


	# clear swap / swap off / swapp on
#	printf " clear swap ( $SwapPath | $($HParser <<< $(($SwapSize*1024))) | $SwapUsedPercent%% used ) \n"

	# get basic/fixed calculating var
	SwapSizeLockedVAR=$SwapSize						# fix swap var cause swapoff change var

	SwapoffPID=/tmp/.smc_cs_pid$RANDOM
	touch $SwapoffPID
	swapoff $SwapPath && rm $SwapoffPID &
#	sleep 100 && rm $SwapoffPID &

	# wait for finish database dumb
	while [[ -f $SwapoffPID ]];do

		# update swap info
		get_swap_info

		# calculate vars
		SwapClearedPercent=$((100-$(($(($SwapUsed*100))/$SwapSizeLockedVAR))))

		# print message
		progressbar  " clear swap  ( $SwapPath | $($HParser <<< $(($SwapSize*1024))) ) " 1 "clearing in progress: $SwapClearedPercent%"
	done

	# enable clear swap and update swap info
	swapon $SwapPath
	get_swap_info

	printf " swap cleared ( $SwapPath | $($HParser <<< $(($SwapSize*1024))) )                                      "
	printf "\n" 






}
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	# check for cronjob execution and cronjob options
	CronExecution=
	if [ -z $(grep "/" <<< "$(tty)") ]; then
		CronExecution=true
		Monochrome=true
	fi

#------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	Reset='\033[0m'
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] || [[ -z $1 ]]; then usage "help dialog" ; fi

#------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $ScriptInformation ]]; then script_information ; fi

#------------------------------------------------------------------------------------------------------------

	# check for root permission
	if [ "$(whoami)" = "root" ]; then echo "";else printf "$LRed Are You Root ?\n";exit 1;fi

#------------------------------------------------------------------------------------------------------------

	# check for required package
	if [[ -n $CheckForRequiredPackages ]]; then check_for_required_packages; fi

#------------------------------------------------------------------------------------------------------------

	get_swap_info

#------------------------------------------------------------------------------------------------------------

	# show swap info
	if [[ -n $ShowSwapInfo ]]; then
		show_swap_info
	fi

#------------------------------------------------------------------------------------------------------------

	if [[ -n $ClearSwap ]]; then
		clear_swap
	fi

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
# TODO write tasks/ issus
# 0.0.1
# write changes

