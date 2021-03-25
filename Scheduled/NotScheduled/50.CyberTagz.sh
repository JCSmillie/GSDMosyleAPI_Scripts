#!/bin/zsh
#
#####################################################################
# 	Read Text file of usernames and tags they should have
#	add those tags to devices assigned to those users
#####################################################################
#  NOTE this script relies on iOS_TagsNAssets.sh to preexport our 
#	device Data
#####################################################################
# JCS 2/26/2021
#
LOG="/usr/local/Smillieware/Logs/iOS_TagsNnames.log"

#The source file is a local file which holds a variable containing
#our MosyleAPI key.  Should look like:
#     MOSYLE_API_key="<<<<<<<<OUR-KEY>>>>>>>>"
# This file should have rights on it as secure as possible.  Runner
# of our scripts needs to read it but no one else.
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"

#Pre-Exported file of all iOS devices on Mosyle from 2.iOS_TagsNUsers.sh
TEMPOUTPUTFILE_Stu="/tmp/Mosyle_active_iOS_Tagz_StudentiPads.txt"

#File Generated outside of this script and mosyle.  Comes from our SIS.
#Format is-> Tag to add,Student UserID
FileKidzNTags="/tmp/Mosyle_CyberTags.csv"

Tagz2Check="CYBER
GATE"


#############################
#        FUNCTIONS          #
#############################

log_line() {
        LINE=$1
        TODAY=$(date '+%a %x %X')
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "50.CyberTagz.sh ++> $TODAY =====> $LINE" >> $LOG
}

AddTagz() {
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"serialnumber\":\"$DeviceSerialNumber\",\"tags\":\"$NewTagz\"}]}"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/devices'
	echo "--"
	log_line "Adding $Tag2Have to $DeviceSerialNumber ($UserID2GetIt)"


}

ParseIt() {
	DeviceSerialNumber=$(echo "$line" | cut -f 2 -d$'\t')
	TAGS=$(echo "$line" | cut -f 4 -d$'\t')
	UserID=$(echo "$line" | cut -f 8 -d$'\t')
	
	if [ "$TAGS" = "null" ] ; then
		TAGS=""
	fi

}

#############################
#          DO WORK          #
#############################
#Grab our Mosyle Tag file from Donatello.
scp root@donatello.gatewayk12.org:/home/jesse_skyward_stuff/Mosyle/Mosyle_CyberTags.csv /tmp/.


## Test to make sure our feeder data files exist.  If not do nothing.
if [ ! -s "$FileKidzNTags" -a ! -r "$FileKidzNTags" ]; then
	log_line "File of students who need tags doesn't exist or is not readable."
	exit 1

elif [ ! -s "$TEMPOUTPUTFILE_Stu" -a ! -r "$TEMPOUTPUTFILE_Stu" ]; then
	log_line "File of current iPad info doesn't exists or is not readable."
	exit 1
fi


IFS=$'\n'

for KidNTag in `cat $FileKidzNTags`; do
	Tag2Have=$(echo "$KidNTag" | cut -f 1 -d , )
	UserID2GetIt=$(echo "$KidNTag" | cut -f 2 -d , )

	#echo "DATA-> $KidNTag"

	#echo "Tag to add to Student-> $Tag2Have"
	#echo "Student User ID-> $UserID2GetIt"

	#Test is user in question has an iPad assigned
	GotDevice=$(grep "$UserID2GetIt" < "$TEMPOUTPUTFILE_Stu" )

	#Yes they have a device
	if [ -n "$GotDevice" ]; then
		line="$GotDevice"
		ParseIt

		#echo "$UserID2GetIt has $DeviceSerialNumber"
		#echo "$UserID2GetIt ($DeviceSerialNumber) has $TAGS"

		#If device has null status for tags we can assume
		#we havent added this tag yet
		if [ "$TAGS" = "null" ]; then
			GotTag=""
			NewTagz="$Tag2Have"
			AddTagz
		#If device has blank status for tags we can assume
		#we havent added this tag yet
		elif [ ! -n "$TAGS" ];then
			GotTag=""
			NewTagz="$Tag2Have"
			AddTagz
		else
		#otherwise search the tags to see if we applied alrady
			GotTag=$(echo "$TAGS" | grep "$Tag2Have" )

			#Check to see if device has already been tagged
			if [ -n "$GotTag" ]; then
				log_line "$DeviceSerialNumber and already has $Tag2Have ($TAGS)"

			else
				#Device doesnt have tag so nothing to do.
				NewTagz="$Tag2Have,$TAGS"
				AddTagz
			fi
		fi

	else
		echo "No iPad found for $UserID2GetIt"
	fi
done

#Check tags the other way.  Make sure no one has something they shouldn't and if so note it.
for Tag2Check in `echo "$Tagz2Check"`; do
	log_line "Sanity Checking $Tag2Check"
	for DeviceWTag in `cat $TEMPOUTPUTFILE_Stu | grep $Tag2Check`; do
		line="$DeviceWTag"
		ParseIt
		# echo "$DeviceSerialNumber"
		# echo "$TAGS"
		# echo "$UserID"

		ShouldIHaveTag=$(cat "$FileKidzNTags" | grep "$UserID")

		if [ -z "$ShouldIHaveTag" ]; then
			log_line "$UserID shouldn't have $Tag2Check tag anymore.  Has $TAGS"
		fi
	done
done

