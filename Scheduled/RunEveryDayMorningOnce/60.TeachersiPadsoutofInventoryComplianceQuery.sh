#!/bin/zsh
#
#####################################################################
# 	Queery Mosyle for group of devices.  Look those devices up
#  and get email addresses.
#####################################################################
#  NOTE this script relies on iOS_TagsNAssets.sh to preexport our 
#	device Data
#####################################################################
# JCS 2/27/2021

LOG="/usr/local/Smillieware/Logs/iOS_TagsNnames.log"

#Pre-Exported file of all iOS devices on Mosyle from 2.iOS_TagsNUsers.sh
DeviceReferenceFile="/tmp/Mosyle_active_iOS_Tagz_TeacheriPads.txt"
DeviceGroup="21"
eMailDomain="@gatewayk12.org"
TempWorkFile="/tmp/WorkFile.txt"
TriggerFileofEmail="/tmp/TeacheriPadsOutOFCompliance.txt"

#####File with Mosyle API Keys in the form of:
# MOSYLE_API_key="YourMosyleAPIKey"
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"

#####
# Junk Variables
####
DeviceNumb=1
UDID="Something"


#############################
#        FUNCTIONS          #
#############################
log_line() {
        LINE=$1
        TODAY=$(date '+%a %x %X')
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "60.TeachersiPadsoutofInventoryComplianceQuery.sh ++> $TODAY =====> $LINE" >> $LOG
}
ParseIt() {
	DeviceSerialNumber=$(echo "$line" | cut -f 2 -d$'\t')
	TAGS=$(echo "$line" | cut -f 4 -d$'\t')
	ASSETTAG=$(echo "$line" | cut -f 5 -d$'\t')
	LastCheckIn=$(echo "$line" | cut -f 6 -d$'\t')
	UserID=$(echo "$line" | cut -f 8 -d$'\t')
	
	if [ "$TAGS" = "null" ] ; then
		TAGS=""
	fi
}



#############################
#          DO WORK          #
#############################
#Clear the work file
rm -Rf $TempWorkFile

#Clear prior outputs
rm -Rf $TriggerFileofEmail

#This is what we are asking Mosyle.  We want to know the members of the device group
content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"iddevicegroup\":\"$DeviceGroup\"}}"
#Ask Mosyle and put output to a variable
output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevicesbygroup') >> $LOG

#Parse the output to get it down to just the meat we need.  Throw that in a TMP file
#                       Only get whats between [ ]         Remove "
echo "$output" | sed -e 's/\(^.*\[\)\(.*\)\(\].*$\)/\2/' | tr -d \" >> $TempWorkFile
	
#Check the work file and make sure devices were reported.	
if cat "$TempWorkFile" | grep "DEVICES_NOTFOUND"; then
	log_line "No Devices are Reported."
	exit 0
else
	HowMany=$(grep -o -i , /tmp/WorkFile.txt | wc -l)
	HowMany=$((HowMany+1))
	log_line "We have $HowMany devices reported to process."
fi

#Loop through output over each value and do things...  This happens until
#we get no return of data.
until [ -z "$UDID" ]; do	
	#Get UDID of Device
	UDID=$(cat $TempWorkFile | cut -d ',' -f "$DeviceNumb")
	
	#If UDID is empty skip this loop
	if [ -z "$UDID" ]; then
		break
	elif [ "$LASTUDID" = "$UDID" ]; then
		log_line "UDUD Repeated itself."
		break
	fi
	
	#Lookup device by UDID
	line=$(grep $UDID < $DeviceReferenceFile)
	
	#Call Parse routine to cut up returned data
	ParseIt
	
	#Build Users Email Address
	Email=$(echo "$UserID""$eMailDomain")
	
	
	# #Show us what you got
	# echo "UDID-> $UDID"
	# echo "Serial-> $DeviceSerialNumber"
	# echo "Email-> $Email"
	# echo "   "
	
	LastSeen=$(python -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LastCheckIn")).strftime('%Y-%m-%d %H:%M:%S'))")
	
	#Log
	log_line "$DeviceSerialNumber ($UDID) assigned to $Email is on the out of compliance list (Last Seen $LastSeen)"
	echo "$Email,$LastCheckIn,$ASSETTAG,$DeviceSerialNumber" >> $TriggerFileofEmail
	
	#Add one so we grab the next UDID for the repeat pass
	let "DeviceNumb=$DeviceNumb + 1"	
	#Track UDID just processed so we can detect on next loop if we are 
	#just reprocessing the same data over and over again.
	LASTUDID="$UDID"		
done


