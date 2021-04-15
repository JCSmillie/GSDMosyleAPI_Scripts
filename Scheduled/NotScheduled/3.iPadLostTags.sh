#!/bin/zsh
#
##################################
# 3.iPadLostTags.sh
#
# This script pulls data from a file
# Miko gives us of iPads which are inventory
# assigned to Students who have no classes.  IE
# they are gone but didn't give us our stuff 
# back.
#
# JCS - 10/15/2020 -v1
#
#

LOG="/usr/local/Smillieware/Logs/iOS_TagsNnames.log"

#####File with Mosyle API Keys in the form of:
# MOSYLE_API_key="YourMosyleAPIKey"
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"

####File with IncidentIQ Keys in the form of:
# apitoken="S0M3KeY"
# siteid="IIQ_SiteID"
# baseurl="https://YourSite.incidentiq.com/api/v1.0
source /tmp/Someplace/.incidentIQ
#apitoken, siteid, and baseurl all come from the source file above

#These files are created by the nightly run of 2.iOS_TagsNUsers.sh
TEMPOUTPUTFILE_Stu="/tmp/Mosyle_active_iOS_Tagz_StudentiPads.txt"
TEMPOUTPUTFILE_Teachers="/tmp/Mosyle_active_iOS_Tagz_TeacheriPads.txt"
TEMPOUTPUTFILE_Limbo="/tmp/Mosyle_active_iOS_Tagz_LimboiPads.txt"

#Dynamically built as we move through the script.
SlackItInfo="/tmp/Mosyle_active_iOS_Tagz_SlackItInfo.txt"
#IFS=$'\n'

#############################
#        FUNCTIONS          #
#############################

log_line() {
        LINE=$1
        TODAY=$(date '+%a %x %X')
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "3.iPadLostTags.sh ++> $TODAY =====> $LINE" >> $LOG
}

AddLostTag() {
	#Run Parsing Routine to get fields from tab delimited data
	ParseIt
	
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"serialnumber\":\"$DeviceSerialNumber\",\"tags\":\"Lost\"}]}"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/devices'
	
	echo "Lost Tag added to $Device" >> "$SlackItInfo"
	
	#Run Lost Mode routine
	EnableLostMode
	#Send a Sound
	#sleep 10
	SendSoundLM
}

EnableLostMode() {
	#Run Parsing Routine to get fields from tab delimited data
	ParseIt
	
	echo "UDID--> $UDID"
	MessagetoSend="This iPad belongs to Gateway School District in Monroeville PA.  We would like it back.  Please reach out to us ASAP!"
	phonenumber="412-372-5300x03122"
	
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"enable\",\"message\":\"$MessagetoSend\",\"phone_number\":\"$phonenumber\"}]}"

	echo "**********<<$content>>**************"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode'
	
	echo "LostMode Enabled on $Device" >> "$SlackItInfo"
}

SendSoundLM() {
	#Run Parsing Routine to get fields from tab delimited data
	ParseIt
	
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"play_sound\"}]}"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode'
	
	echo "Make a Sound Command sent to $Device" >> "$SlackItInfo"
}

RequestLocation(){
	#Run Parsing Routine to get fields from tab delimited data
	ParseIt
	
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"request_location\"}]}"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode'
	
	echo "Location was requested from $Device" >> "$SlackItInfo"
}

DisableLostMode(){
	ParseIt
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"devices\":\"$UDID\",\"operation\":\"disable\"}]}"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/lostmode'

	
	echo "LostMode Disabled on $Device" >> "$SlackItInfo"
}


ParseIt() {
	UDID=$(echo "$line" | cut -f 1 -d$'\t')
	DeviceSerialNumber=$(echo "$line" | cut -f 2 -d$'\t')
	CURRENTNAME=$(echo "$line" | cut -f 3 -d$'\t')
	TAGS=$(echo "$line" | cut -f 4 -d$'\t')
	ASSETTAG=$(echo "$line" | cut -f 5 -d$'\t')
	ENROLLMENT_TYPE=$(echo "$line" | cut -f 7 -d$'\t')
}

#Query Asset Group and return relative serials.  Save to /tmp/MissingiPads.txt
IIQ_MissingiPads() {
	#THIS IS WHAT IM TRYING TO FIGURE OUT
	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/assets/?$s=1000"
	content="{\"OnlyShowDeleted\":false,\"Filters\":[{\"Facet\":\"View\",\"Id\":\"a10a7ea5-3004-eb11-9fb4-2818784aec2c\"}],\"FilterByViewPermission\":true}"

	curl -s -k -H "SiteId: $siteid" -H "$Auth" -H "Client: ApiClient" -X POST -d "$content" "$Query" -H "Content-Type: application/json" | grep "SerialNumber\":" | cut -d ':' -f 2 | cut -d ',' -f 1 | tr -d \" > /tmp/MissingiPads.txt
}


###############################
#   Check Condtions to work   #
###############################
#First Make sure we have what we need
# #If we have a slack data file from prior run delete it.
if [ -s "$SlackItInfo" ]; then
	rm -Rf "$SlackItInfo"
fi

if [ ! -s "$TEMPOUTPUTFILE_Stu" ]; then
	log_line "$TEMPOUTPUTFILE_Stu is missing.  Can't continue."
	exit 1
elif [ ! -s "$TEMPOUTPUTFILE_Limbo" ]; then
	log_line "$TEMPOUTPUTFILE_Limbo is missing.  Can't continue."
	exit 1
elif [ ! -s "/tmp/MissingiPads.txt" ]; then
	log_line "/tmp/MissingiPads.txt is missing.  Can't continue."
	exit 1
fi

#If we have a slack data file from prior run delete it.
if [ -s "$SlackItInfo" ]; then
	rm -Rf "$SlackItInfo"
fi





#############################
#          Do Work          #
#############################
#Lets get a list together of the Lost Devices we are already Claiming
KnownLostDevices=$(grep "Lost" < "$TEMPOUTPUTFILE_Stu")


exec 3< /tmp/MissingiPads.txt

until [ $done ]
do
    read <&3 myline
    if [ $? != 0 ]; then
        done=1
        continue
    fi

	#Set line to Device variable
	Device="$myline"
	
	#Strip any extra carriages	
	Device=$(echo "$Device" | tr -d "[:space:]")
	
	#Check to see if iPad is in Limbo (unassigned)
	DeviceInLimbo=$(grep "$Device" < "$TEMPOUTPUTFILE_Limbo")
	DeviceKnownLost=$(echo "$KnownLostDevices" | grep "$Device")
	DeviceAssigned=$(grep "$Device" < "$TEMPOUTPUTFILE_Stu")

	#Device is in Limbo (Unassigned)
	if [ -n "$DeviceInLimbo" ]; then
		log_line "iPad is in Limbo ($Device.)  Needs Manual Intervention."
		echo "iPad is in Limbo ($Device.)  Needs Manual Intervention." >> "$SlackItInfo"
		DisableLostMode
		
		#Device is already Tagged/known to be Lost in Mosyle
	elif [ -n "$DeviceKnownLost" ]; then
		log_line "iPad is known to be Missing.  No Tags need Added."
		line="$DeviceKnownLost"
		
		#Make sure Lost mode is on
		EnableLostMode
		
		#Send a Sound
		sleep 10
		SendSoundLM
		
	elif [ -n "$DeviceAssigned" ]; then
		log_line "Need to add Lost Tag to $Device"
		line="$DeviceAssigned"
		AddLostTag

		
	else
		log_line "Mosyle doesn't know $Device.  Needs Manual Intervention."
		echo "$Device is not Registered to Mosyle.  Needs Manual Intervention." >> "$SlackItInfo"
	fi
done

#######################################
# Check iPads tagged as Lost and make
# Sure they still should be.
#######################################
#Get a list of ONLY Serial numbers from our lost data.
grep "Lost" < "$TEMPOUTPUTFILE_Stu" | cut -f 2 -d$'\t' | tr " " "\n" > /tmp/KnownLostSerialsOnly.txt
grep "Lost" < "$TEMPOUTPUTFILE_Teachers" | cut -f 2 -d$'\t' | tr " " "\n" >> /tmp/KnownLostSerialsOnly.txt
grep "Lost" < "$TEMPOUTPUTFILE_Limbo" | cut -f 2 -d$'\t' | tr " " "\n" >> /tmp/KnownLostSerialsOnly.txt

#Parse our lost list
for SerialOnlyKnownLostDevice in `cat /tmp/KnownLostSerialsOnly.txt`; do
	#Get the Serial
	echo "Confirming Serial Number $SerialOnlyKnownLostDevice"
		
	#Figure out if Device from Lost List is still in our wanted list.
	DeviceLostButNotWanted=$(grep "$SerialOnlyKnownLostDevice" < "$FileFromMikoOfLostSouls" )
	
	#Device is in Limbo (Unassigned)
	if [ -z "$DeviceLostButNotWanted" ]; then
		log_line "Device is lost ($SerialOnlyKnownLostDevice) but not wanted.  PLEASE REMOVE TAG."
		echo "Device is lost ($SerialOnlyKnownLostDevice) but not wanted.  PLEASE REMOVE TAG." >> "$SlackItInfo"
	fi
done



#######################################
# Lets make some reports.  If stuff happened
# that mattered then Slack it.
#######################################
#Is there any apps which are new to our repo
if [ -s "$SlackItInfo" ]; then
	log_line "There appears to be noteworthy changes.  Will Slack out."
		
	echo "3.iPadLostTags.sh just ran and this happened" > /tmp/3.iPadLostTags.sh-2Slack.txt

	cat $SlackItInfo >> /tmp/3.iPadLostTags.sh-2Slack.txt
	cat	/tmp/3.iPadLostTags.sh-2Slack.txt | /usr/local/bin/slacktee.sh -a warning -c mdm_activity
	
else
	log_line "There doesnt appear to be any new apps.  No Slack message will be posted."
fi


