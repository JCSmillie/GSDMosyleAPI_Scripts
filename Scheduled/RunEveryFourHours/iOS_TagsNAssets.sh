#!/bin/bash

################################################################
#
#	iOS_TagsNAssets.sh  
#		Script pulls list of all AppleTVs in Mosyle and makes
#		sure they have asset tags, tags, and named after their tags.
#
#		JCS - 3/19/2020  -v1
#
################################################################
LOG="/usr/local/Smillieware/Logs/iOS_TagsNnames.log"

#The source file is a local file which holds a variable containing
#our MosyleAPI key.  Should look like:
#     MOSYLE_API_key="<<<<<<<<OUR-KEY>>>>>>>>"
# This file should have rights on it as secure as possible.  Runner
# of our scripts needs to read it but no one else.
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"

source /tmp/Someplace/.incidentIQ
#apitoken, siteid, and baseurl all come from the source file above.
Auth=$(echo "Authorization: Bearer $apitoken")


TEMPOUTPUTFILE="/tmp/Mosyle_active_iOS.txt"
IFS=$'\n'

#Remove any prior works generated by this script
rm -Rf $TEMPOUTPUTFILE
rm -Rf /tmp/TEMP.json


################################
#          FUNCTIONS           #
################################
log_line() {
        LINE=$1
        TODAY=`date '+%a %x %X'`
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "iOS_TagsNAssets.sh ++> $TODAY =====> $LINE" >> $LOG
}

IIQ_GetAssetTag() {
	#Ask InicdentIQ what a Devices tag is.
	Query="$baseurl/assets/serial/$SERIALNUMBER"
	ASSETTAG=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query" | grep "AssetTag" | cut -d ':' -f 2 | cut -d ',' -f 1 | head -1 | tr -d \")

}


################################
#            DO WORK           #
################################

#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	#Note this script is quering for iOS devices but it could easly be changed to do Macs by changing "ios" below to "macos" instead.
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"specific_columns\":\"serial_number,asset_tag\",\"page\":$THEPAGE}}"
	#echo "$content"
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices') >> $LOG
	
	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(echo $output | grep DEVICES_NOTFOUND)
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		log_line "Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi

	#Now take the JSON data we received and parse it into tab
	#delimited output.
	echo "$output" | awk 'BEGIN{FS=",";RS="},{"}{print $0}' | grep serial_number| perl -pe 's/.*"serial_number":"(.*?)","asset_tag":"?(.*)"*.*/\1\t\2\t\3/' | sed 's/"//' >> "$TEMPOUTPUTFILE"
done

#Go through our data file and see whats going on
for line in `cat $TEMPOUTPUTFILE`; do
	#ok so now we are going to process this data:
	SERIALNUMBER=$(echo "$line" | cut -f 1 -d$'\t')
	ASSETTAG=$(echo "$line" | cut -f 2 -d$'\t')

	####This ine was for troubleshooting.  Uncommenting will show you
	####the data we are about to work on.
	#echo "Serial-> $SERIALNUMBER / Asset Tag-> $ASSETTAG"

	#Check the asset tag field.  Make sure its set.
	if [[ -z "$ASSETTAG" ]] || [[ "$ASSETTAG" == "null" ]]; then
		log_line "Unit with serial $SERIALNUMBER has no Asset tag set."
		
		#Mosyle didnt know the value needed for this machine.  Lets
		#ask the district inventory.  This function can be adapted
		#to any system in the end it just needs to fill the ASSETTAG
		#variable with the tag that belongs to this serial number.
	    log_line "Asking Inventory for GSD tag of hardware."
		#Query our home brew inventory system and get back a tag.
		#ASSETTAG=$(curl -s -k "http://aligator.gatewayk12.org/testing/inventory/index.php?-table=invtable2&-action=export_xml&-cursor=0&-skip=0&-limit=30&-mode=list&serial=$SERIALNUMBER" | grep "<id>" | head -1 | /usr/bin/awk -F'<id>|</id>' '{print $2}' )
		IIQ_GetAssetTag

		if [ -z "$ASSETTAG" ]; then
			#GSD Inventory doesnt know this machine
			log_line "IncidentIQ also doesnt know this machine.  No luck!"
		
		else
			#GSD Inventory does know this machine.  Lets use it to inform Mosyle
	        log_line "File says unit with serial $SERIALNUMBER should have tag number $ASSETTAG.  Setting..."
			content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"serialnumber\":\"$SERIALNUMBER\",\"asset_tag\":\"$ASSETTAG\"}]}"
			curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/devices' >> $LOG
			echo " " >> $LOG

		fi
		
	fi
	
done


