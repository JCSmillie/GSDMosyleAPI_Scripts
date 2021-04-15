#!/bin/zsh
#
##################################
# 99.MassiPad2Limbo.sh
#
# Process list of serials and mark those
# iPads to Limbo (unassigned) status.  I'm
# relying on my other scripts for the initial
# data; see 2.iOS_TagsNUsers.sh in the Scheduled
# daily folder.
#
# JCS - 4/15/2021 -v1
#
#


iPads2Unassign="/Users/jsmillie/GitHub/Scriptz/Mosyle_API/MassiPad2Limbo/serials.txt"
#This data comes from 2.iOS_TagsNUsers.sh which runs nightly.
MosyleiPads="/tmp/Mosyle_active_iOS_Tagz_StudentiPads.txt"
LOG="/usr/local/Smillieware/Logs/iOS_Assigned2Limbo.log"

#####File with Mosyle API Keys in the form of:
# MOSYLE_API_key="YourMosyleAPIKey"
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"


IFS=$'\n'

#Log Function
log_line() {
        LINE=$1
        TODAY=$(date '+%a %x %X')
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "99.MassiPad2Limbo.sh ++> $TODAY =====> $LINE" >> $LOG
}

#Go through our output from Mosyle and drop critical info
#to variables.
ParseIt() {
	UDID=$(echo "$line" | cut -f 1 -d$'\t')
	DeviceSerialNumber=$(echo "$line" | cut -f 2 -d$'\t')
	CURRENTNAME=$(echo "$line" | cut -f 3 -d$'\t')
	TAGS=$(echo "$line" | cut -f 4 -d$'\t')
	ASSETTAG=$(echo "$line" | cut -f 5 -d$'\t')
	ENROLLMENT_TYPE=$(echo "$line" | cut -f 7 -d$'\t')
}



#############################
#          Do Work          #
#############################
#Pull all serials from file and parse to get UDiD numbers.
exec 3< $iPads2Unassign

until [ $done ]
do
    read <&3 myline
    if [ $? != 0 ]; then
        done=1
        continue
    fi
	
	echo "Looking for $myline"
	
	#Run the serial against the Mosyle iPad File
	line=$(cat "$MosyleiPads" | grep "$myline" )
	
	#Is $line zero'd? We didnt find that serial in file.  Skip it.
	if [ -z $line ]; then
		echo "$myline does appear in Mosyle export.  Can't do anything."
		continue
	else
		
		#Serial was found, parse the return
		ParseIt
		
		#if this is our first entry just fill the variable
		if [ -z "$UDiDs" ]; then
			UDiDs="$UDID"
		else
			#all others are additons to the variable 
			UDiDs=$(echo "$UDiDs,$UDID")
		fi
	fi
done


#Call out to Mosyle MDM to submit list of UDIDs which need Limbo'd
content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDiDs\",\"operation\":\"change_to_limbo\"}]}"
curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/bulkops'
