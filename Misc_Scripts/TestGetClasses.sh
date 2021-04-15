#!/bin/bash
#
# Script to query Mosyle and return a list of class names and the student usernames
# who are in those classes.
#


#The source file is a local file which holds a variable containing
#our MosyleAPI key.  Should look like:
#     MOSYLE_API_key="<<<<<<<<OUR-KEY>>>>>>>>"
# This file should have rights on it as secure as possible.  Runner
# of our scripts needs to read it but no one else.
source /tmp/Someplace/.MosyleAPI
APIKey="$MOSYLE_API_key"
TEMPOUTPUTFILE="/tmp/tmp.txt"

LOG=/dev/null

log_line() {
	echo "$1"
}

ParseIt() {
	ClassID=$(echo "$line" | cut -f 1 -d$'\t')
	ClassName=$(echo "$line" | cut -f 2 -d$'\t')
	Students=$(echo "$line" | cut -f 3 -d$'\t' | tr -d \" | tr -d [ | tr -d ])
}


#Clear out our files
rm -Rf $TEMPOUTPUTFILE

THECOUNT=0

# Connect to Mosyle API multiple times (for each page) so we
# get all of the available data.
while true; do
	let "THECOUNT=$THECOUNT+1"
	THEPAGE="$THECOUNT"
	
	content="{\"accessToken\":\"$APIKey\",\"options\":{\"specific_columns\":[\"id\",\"class_name\",\"students\"],\"page\":$THEPAGE}}"
	output=$(curl -s -k -X POST -d 'content='$content 'https://managerapi.mosyle.com/v2/listclasses') >> $LOG

	#Detect we just loaded a page with no content and stop.
	LASTPAGE=$(echo $output | grep NO_CLASSES_FOUND)
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
	echo "$output" | awk 'BEGIN{FS=",";RS="},{"}{print $0}' | grep id | perl -pe 's/.*"id":"(.*?)","class_name":"?(.*)","students":"?(.*)"*.*/\1\t\2\t\3\t\4/' | sed 's/"//' >> "$TEMPOUTPUTFILE"
	
done

