#!/bin/bash

################################################################
#
#	iOS_TagsNUsers.sh  
#		Script pulls all iPads from Mosyle and sorts them out 
#		into other files.  These files are utilized after the
#		fact by other scripts.
#
#		JCS - 10/15/2020  -v1
#
################################################################
LOG="/usr/local/Smillieware/Logs/iOS_TagsNnames.log"
IFS=$'\n'

#The source file is a local file which holds a variable containing
#our MosyleAPI key.  Should look like:
#     MOSYLE_API_key="<<<<<<<<OUR-KEY>>>>>>>>"
# This file should have rights on it as secure as possible.  Runner
# of our scripts needs to read it but no one else.
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"

#Locations of final sorted files.  Output seperates student 1:1
#ipads, Staff iPads, and then Limbo/unassigned iPads.
TEMPOUTPUTFILE_Stu="/tmp/Mosyle_active_iOS_Tagz_StudentiPads.txt"
TEMPOUTPUTFILE_Teachers="/tmp/Mosyle_active_iOS_Tagz_TeacheriPads.txt"
TEMPOUTPUTFILE_Limbo="/tmp/Mosyle_active_iOS_Tagz_LimboiPads.txt"


################################
#          FUNCTIONS           #
################################
log_line() {
        LINE=$1
        TODAY=`date '+%a %x %X'`
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "iOS_TagsNUsers.sh ++> $TODAY =====> $LINE" >> $LOG
}

################################
#            DO WORK           #
################################
#Remove any prior works generated by this script
rm -Rf "$TEMPOUTPUTFILE_Stu"
rm -Rf "$TEMPOUTPUTFILE_Teachers"
rm -Rf "$TEMPOUTPUTFILE_Limbo"
rm -Rf /tmp/TEMP.json

#Initialize the base count variable. This will be
#used to figure out what page we are on and where
#we end up.
THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"os\":\"ios\",\"specific_columns\":\"deviceudid,serial_number,device_name,tags,asset_tag,userid,date_app_info\",\"page\":$THEPAGE}}"
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listdevices') >> $LOG
	



	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(echo $output | grep DEVICES_NOTFOUND)
	if [ -n "$LASTPAGE" ]; then
		let "THECOUNT=$THECOUNT-1"
		log_line "Yo we are at the end of the list (Last good page was $THECOUNT)"
		break
	fi

	echo " "
	echo "Page $THEPAGE data."
	echo "-----------------------"

	#Now take the JSON data we received and parse it into tab
	#delimited output.

	#Right from the git go exclude any results which are for General (Limbo) iPads, Shared iPads, Staff iPads, or Teacher iPads.
	#This creates the list of student iPads
	echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | grep -v GENERAL | grep -v SHARED | grep -v Teachers | grep -v Staff | grep -v Leader | grep serial_number |  perl -pe 's/.*"deviceudid":"?(.*?)"?,"serial_number":"(.*?)","device_name":"?(.*?)"?,"tags":"?(.*?)"?,"asset_tag":"?(.*?)"?,"date_app_info":"?(.*?)","enrollment_type":"?(.*?)","userid":"?(.*?)","username":"?(.*?)","usertype":"?(.*?)",*.*/\1\t\2\t\3\t\4\t\5\t\6\t\7\t\8\t\9/' >> "$TEMPOUTPUTFILE_Stu"
	
	#Now a file with just Teachers/Staff in it.
	echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | grep -v GENERAL | grep -v SHARED|grep -v Student | grep serial_number |  perl -pe 's/.*"deviceudid":"?(.*?)"?,"serial_number":"(.*?)","device_name":"?(.*?)"?,"tags":"?(.*?)"?,"asset_tag":"?(.*?)"?,"date_app_info":"?(.*?)","enrollment_type":"?(.*?)","userid":"?(.*?)","username":"?(.*?)","usertype":"?(.*?)",*.*/\1\t\2\t\3\t\4\t\5\t\6\t\7\t\8\t\9/' >> "$TEMPOUTPUTFILE_Teachers"
	
	#Finally a file with all the Limbo devices
		echo "$output"| awk 'BEGIN{FS=",";RS="},{"}{print $0}' | grep GENERAL | grep serial_number |  perl -pe 's/.*"deviceudid":"?(.*?)"?,"serial_number":"(.*?)","device_name":"?(.*?)"?,"tags":"?(.*?)"?,"asset_tag":"?(.*?)"?,"date_app_info":"?(.*?)","enrollment_type":"?(.*?)",*.*/\1\t\2\t\3\t\4\t\5\t\6/' >> "$TEMPOUTPUTFILE_Limbo"
done


#At this point I would run a follow up script to used the data we parsed above. All data above ends up 
#in an csv style sheet so its easy to use the "cut" command to parse that data.