#!/bin/zsh


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
#Format is-> OutsideSchool Code (matched later to make tags),Student UserID
FileOutSidePlacementKidz="/tmp/MosyleSpecEdFlags.csv"


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

AddTagz() {
	content="{\"accessToken\":\"$APIKey\",\"elements\":[{\"serialnumber\":\"$DeviceSerialNumber\",\"tags\":\"$NewTagz\"}]}"
	curl  -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/devices'


}

ParseIt() {
	#UDID=$(echo "$line" | cut -f 1 -d$'\t')
	DeviceSerialNumber=$(echo "$line" | cut -f 2 -d$'\t')
	#CURRENTNAME=$(echo "$line" | cut -f 3 -d$'\t')
	TAGS=$(echo "$line" | cut -f 4 -d$'\t')
	#ASSETTAG=$(echo "$line" | cut -f 5 -d$'\t')
	#ENROLLMENT_TYPE=$(echo "$line" | cut -f 6 -d$'\t')
	UserID=$(echo "$line" | cut -f 8 -d$'\t')
	
	if [ "$TAGS" = "null" ] ; then
		TAGS=""
	fi

}





scp root@donatello.gatewayk12.org:/home/jesse_skyward_stuff/Mosyle/MosyleSpecEdFlags.csv /tmp/.

IFS=$'\n'

for OutSideStudent in `cat $FileOutSidePlacementKidz`; do
	OutSideStuUserID=$(echo "$OutSideStudent" | cut -f 1 -d , )
	OutSideSchoolID=$(echo "$OutSideStudent" | cut -f 2 -d , )
	
	echo "DATA-> $OutSideStudent"

	echo "Student User ID-> $OutSideStuUserID"
	echo "With School ID-> $OutSideSchoolID"
	
	GotDevice=$(grep "$OutSideStuUserID" < "$TEMPOUTPUTFILE_Stu" )
	
	if [ -n "$GotDevice" ]; then
		line="$GotDevice"
		ParseIt
		
		echo "$OutSideStuUserID has $DeviceSerialNumber"
		echo "$DeviceSerialNumber has $TAGS"
		
		if [ "$OutSideSchoolID" = "032" ]; then
			echo "Student is HOME SCHOOL"
			NewTagz="HomeSchool,$TAGS"
			
		elif [ "$OutSideSchoolID" = "045" ]; then
			echo "Student is PACE"
			NewTagz="PACE,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "047" ]; then
			echo "Student is Pressley Ridge"
			NewTagz="PressleyRidge,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "049" ]; then
			echo "Student is Children's Institute"
			NewTagz="ChildrensInstitute,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "054" ]; then
			echo "Student is Sunrise"
			NewTagz="Sunrise,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "056" ]; then
			echo "Student is Western PA School for Blind"
			NewTagz="WPSB,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "057" ]; then
			echo "Student is Western PA School for Deaf"
			NewTagz="WPSD,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "ESE" ]; then
			echo "Student is Easter Seal"
			NewTagz="EasterSeal,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "NEW" ]; then
			echo "Student is NewStory"
			NewTagz="NewStory,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "HFN" ]; then
			echo "Student is Holy Family"
			NewTagz="HolyFamily,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "ALD" ]; then
			echo "Student is Adelphoi"
			NewTagz="Adelphoi,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "FRA" ]; then
			echo "Student is Friendship Academy"
			NewTagz="FriendshipAcad,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "WAT" ]; then
			echo "Student is Watson Institute Social Center for Academic Achievement"
			NewTagz="WISCA,SpecEd,$TAGS"
			
		elif [ "$OutSideSchoolID" = "5AB" ]; then
			echo "Student is Adelphoi"
			NewTagz="PLEA,SpecEd,$TAGS"

		fi
		
		AddTagz
		
	else
		echo "No iPad found for $OutSideStuUserID"
	fi
done
