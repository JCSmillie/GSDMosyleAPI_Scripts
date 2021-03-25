#/!/bin/zsh
#
###############################################
#
#  Emailer.  Looks for files to exist, processes
# those files and sends emails.  This is a compliment
# to the 60.X Inventory Compliance Scripts
#
################################################
#
TriggerFileofEmail="/tmp/StudentiPadsOutOFCompliance.txt"
LOG="/usr/local/Smillieware/Logs/iPadScoffemails.txt"

####File with IncidentIQ Keys in the form of:
# apitoken="S0M3KeY"
# siteid="IIQ_SiteID"
# baseurl="https://YourSite.incidentiq.com/api/v1.0
source /tmp/Someplace/.incidentIQ
#apitoken, siteid, and baseurl all come from the source file above



######################
# Declare Functions  #
######################
#This function is for logging.  The hope is to output to both
#the local display and load up our internal log which will be
#emailed later.
log_line() {
        LINE=$1
        TODAY=`date '+%a %x %X'`
        #Print on stdout
        echo "$TODAY =====>$LINE"
        #Log to file
        echo "90.EmailiPadComplinanceScoffs-RegStu.sh ++> $TODAY =====> $LINE" >> $LOG
}

IIQ_Lookup() {
	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/assets/serial/$DeviceSerialNumber"

	#Ask IIQ if the serial number applied has tickets open.  Use cut to just get back true or false
	HasTickets=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query" | grep HasOpenTickets | cut -d ':' -f 2 | cut -d ',' -f 1)
	#Hack off white spaces
	HasTickets="${HasTickets//[[:space:]]/}"
	
	#Ask IIQ if iPad has the PreviousOwner field attributed.  Will return nothing if iPad is deployed
	#and a users ID number if it is NOT deployed.  ID number is that of the former user.  We only care
	#about this to know if the ipad is deploy or not.  Value of the data doesn't matter.
	PreviousOwner=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query" | grep PreviousOwner | cut -d ':' -f 2 | cut -d ',' -f 1 | tr -d \")
	PreviousOwner="${PreviousOwner//[[:space:]]/}"
	
	#Ask IIQ the username of who the iPad is assigned to.  This could be either current or previous
	#depending on the state of the iPad (assigned/unassigned)
	DeviceAssignd=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query" | grep "Username\":" | cut -d ':' -f 2 | cut -d ',' -f 1 | tr -d \")
	#Hack off white spaces
	DeviceAssignd="${DeviceAssignd//[[:space:]]/}"
}


#Grab Feeder file of Student Data
scp root@donatello.gatewayk12.org:/home/jesse_skyward_stuff/Mosyle/Mosyle_StuRef.csv /tmp/.

#Clear our temporary stores
rm -Rf /tmp/ToSec*.txt
rm -Rf /tmp/StuProcessErrors.txt



#############################
#          DO WORK          #
#############################
if [ ! -f "$TriggerFileofEmail" ]; then
	log_line "Trigger file doesn't exist.  Cant do anything!"
	exit 1
fi

for emailme in `cat $TriggerFileofEmail`; do

	email=$(echo "$emailme" | cut -f 1 -d",")
	LastCheckIn=$(echo "$emailme" | cut -f 2 -d",")
	AssetTag=$(echo "$emailme" | cut -f 3 -d",")
	DeviceSerialNumber=$(echo "$emailme" | cut -f 4 -d",")
	LastSeen=$(python -c "import datetime; print(datetime.datetime.fromtimestamp(int("$LastCheckIn")).strftime('%Y-%m-%d %H:%M:%S'))")

	
	ExtendedStuData=$(cat /tmp/Mosyle_StuRef.csv | grep $email | head -1)
	#echo "ESD-> $ExtendedStuData"
	
	#Using Head to only take first result.. just in case someone is double scheduled.
	StuIDNum=$(echo "$ExtendedStuData" | cut -f 3 -d",")
	StuName=$(echo "$ExtendedStuData" | cut -f 4 -d"," )
	parent=$(echo "$ExtendedStuData" | cut -f 5 -d"," )
	HomeRoomTeacher=$(echo "$ExtendedStuData" | cut -f 6 -d"," )
	School=$(echo "$ExtendedStuData" | cut -f 7 -d"," )
	School="${School//[[:space:]]/}"


	#Query IncidentIQ
	IIQ_Lookup
	

	if [ "$HasTickets" = "true" ]; then
		log_line "There is an open ticket for $AssetTag.  Possibly related.  Annoy mail will not be send."
		echo "GSD Device #$AssetTag-> On list for not checking in, but has open ticket. No Email sent." >> /tmp/StuProcessErrors.txt
		
	elif [ ! -z "$PreviousOwner" ] || [ -z "$DeviceAssignd" ]; then
		log_line "IncidentIQ doesn't think this device ($AssetTag) is assigned to anyone.  Not emailing anyone."
		echo "GSD Device #$AssetTag-> IIQ says device is not deployed.  No Email sent." >> /tmp/StuProcessErrors.txt
		echo "$PreviousOwner / $DeviceAssignd"
		
	elif [ ! "$email" = "$DeviceAssignd" ]; then
		log_line "Mosyle and IIQ assignment knowledge differ on $AssetTag.  Recheck manually  No email sent."
		echo "GSD Device #$AssetTag-> Mosyle ($email) and IIQ ($DeviceAssignd) assignment info mismatch.  No email sent." >> /tmp/StuProcessErrors.txt
		
	else	
		if [ -z "$School" ]; then
			#We are here if student is not in the Skyward Feeder File
			log_line "$email is not in school file.  Epic Fail"
			echo "GSD Device #$AssetTag-> $email is not in Skyward Output file." >> /tmp/StuProcessErrors.txt
		
		elif [ -z "$parent" ]; then
			#We are here if there is no parent email in the Skyward feeder file
			log_line "Parent field for $email is blank.  Will only mail Student, Teacher ($HomeRoomTeacher), and building Sec ($School)"
			echo "GSD Device #$AssetTag-> Email to $email, $HomeRoomTeacher, and School Sec $School" >> /tmp/StuProcessErrors.txt
			echo "Device assigned to $StuName ($email) hasn't checked in to inventory since $LastSeen.  Student and home room teacher ($HomeRoomTeacher) mailed.  Please follow up on this." >> /tmp/ToSec$School.txt

			#Email Student
			echo "The iPad assigned to you ($email) with GSD tag #$AssetTag has not checked in for inventory since $LastSeen.  Per GSD Technology Proceedures (see the Incident IQ Knowledge base) all Student iPads MUST CHECK IN at least every 7 days.  Please ensure at this time your device is charged and on a wifi network.  Try to use it.  If you are having issues please email helpdesk@gatewayk12.org or call 412-373-5870 option 4.  Thank you." > /tmp/Email1.txt
			/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Email1.txt -t $email -u "<<iPadCompliance>> GSD Assigned iPad out of Inventory Compliance" -l $LOG -o tls=no > /dev/null 2>&1
			#Email Teacher
			echo "The iPad assigned to $StuName with GSD tag #$AssetTag has not checked in for inventory since $LastSeen which normally means they are not using it.  Student and Parent ($parent) emailed.  Please follow up with them.  You are receiving this email because this student is in your homeroom per Skyward.  If not the case please forward to proper teacher." > /tmp/Email2.txt
			echo " " >> /tmp/Email2.txt
			echo "NOTE: If this student is not in your HOMEROOM at all please make the office secretary aware so this sechedule snafu can be corrected.  Thank you" >> /tmp/Email2.txt
			/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Email2.txt -t $HomeRoomTeacher -u "<<iPadCompliance>> iPad assigned to $StuName is not checking in." -l $LOG -o tls=no > /dev/null 2>&1

				
		else
			log_line "We will email $StuName ($email) and $parent about iPad with GSD tag #$AssetTag last seen on $LastSeen.  Copying $HomeRoomTeacher and building Sec ($School)"
		
			echo "GSD Device #$AssetTag-> Email to $email, $parent, $HomeRoomTeacher, and School Sec $School" >> /tmp/StuProcessErrors.txt
			echo "Device assigned to $StuName ($email) hasn't checked in to inventory since $LastSeen.  Student, $parent, and home room teacher ($HomeRoomTeacher) mailed.  Please follow up on this." >> /tmp/ToSec$School.txt

			#Email Student
			echo "The iPad assigned to you ($email) with GSD tag #$AssetTag has not checked in for inventory since $LastSeen.  Per GSD Technology Proceedures (see the Incident IQ Knowledge base) all Student iPads MUST CHECK IN at least every 7 days.  Please ensure at this time your device is charged and on a wifi network.  Try to use it.  If you are having issues please email helpdesk@gatewayk12.org or call 412-373-5870 option 4.  Thank you." > /tmp/Email1.txt
			/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Email1.txt -t $email,$parent -u "<<iPadCompliance>> GSD Assigned iPad out of Inventory Compliance" -l $LOG -o tls=no > /dev/null 2>&1
			#Email Teacher
			echo "The iPad assigned to you $StuName with GSD tag #$AssetTag has not checked in for inventory since $LastSeen which normally means they are not using it.  Student and Parent ($parent) emailed.  Please follow up with them.  You are receiving this email because this student is in your homeroom per Skyward.  If not the case please forward to proper teacher." > /tmp/Email2.txt
			echo " " >> /tmp/Email2.txt
			echo "NOTE: If this student is not in your HOMEROOM at all please make the office secretary aware so this sechedule snafu can be corrected.  Thank you" >> /tmp/Email2.txt
			/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Email2.txt -t $HomeRoomTeacher -u "<<iPadCompliance>> iPad assigned to $StuName is not checking in." -l $LOG -o tls=no > /dev/null 2>&1		
		fi
	fi

done

# 030 GHS, 020 GMS, 016 MSMS, 009 CSE, 015 UP, 012 RAM, 014 EV

if [ -f "/tmp/ToSec009.txt" ]; then
	log_line "Need to send email to CSE"

	echo "The following iPads in your building are out of compliance with inventory.  Where possible Parents and homeroom teachers were contacted.  Please follow up." > /tmp/Emailout.txt
	echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
	cat /tmp/ToSec009.txt >> /tmp/Emailout.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t pdragovich@gatewayk12.org -u "<<iPadCompliance>> Student iPads in your building out of compliance" -l $LOG -o tls=no > /dev/null 2>&1
fi

if [ -f "/tmp/ToSec015.txt" ]; then
	log_line "Need to send email to UP"

	echo "The following iPads in your building are out of compliance with inventory.  Where possible Parents and homeroom teachers were contacted.  Please follow up." > /tmp/Emailout.txt
	echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
	cat /tmp/ToSec015.txt >> /tmp/Emailout.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t rsalerno@gatewayk12.org -u "<<iPadCompliance>> Student iPads in your building out of compliance" -l $LOG -o tls=no > /dev/null 2>&1
fi

if [ -f "/tmp/ToSec012.txt" ]; then
	log_line "Need to send email to RAM"

	echo "The following iPads in your building are out of compliance with inventory.  Where possible Parents and homeroom teachers were contacted.  Please follow up." > /tmp/Emailout.txt
	echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
	cat /tmp/ToSec012.txt >> /tmp/Emailout.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t cveverka@gatewayk12.org -u "<<iPadCompliance>> Student iPads in your building out of compliance" -l $LOG -o tls=no > /dev/null 2>&1
fi

if [ -f "/tmp/ToSec014.txt" ]; then
	log_line "Need to send email to EV"

	echo "The following iPads in your building are out of compliance with inventory.  Where possible Parents and homeroom teachers were contacted.  Please follow up." > /tmp/Emailout.txt
	echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
	cat /tmp/ToSec014.txt >> /tmp/Emailout.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t jpack@gatewayk12.org -u "<<iPadCompliance>> Student iPads in your building out of compliance" -l $LOG -o tls=no > /dev/null 2>&1
fi

if [ -f "/tmp/ToSec016.txt" ]; then
	log_line "Need to send email to MSMS"

	echo "The following iPads in your building are out of compliance with inventory.  Where possible Parents and homeroom teachers were contacted.  Please follow up." > /tmp/Emailout.txt
	echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
	cat /tmp/ToSec016.txt >> /tmp/Emailout.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t ccapell@gatewayk12.org -u "<<iPadCompliance>> Student iPads in your building out of compliance" -l $LOG -o tls=no > /dev/null 2>&1
fi

if [ -f "/tmp/ToSec020.txt" ]; then
	log_line "Need to send email to GMS"

	echo "The following iPads in your building are out of compliance with inventory.  Where possible Parents and homeroom teachers were contacted.  Please follow up." > /tmp/Emailout.txt
	echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
	cat /tmp/ToSec020.txt >> /tmp/Emailout.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t ddias@gatewayk12.org -u "<<iPadCompliance>> Student iPads in your building out of compliance" -l $LOG -o tls=no > /dev/null 2>&1
fi

if [ -f "/tmp/ToSec030.txt" ]; then
	log_line "There are iPads in scoff for GHS"
	echo "ATTN: Double check the list for GHS iPads...  No sec was mailed." >> /tmp/StuProcessErrors.txt
fi

#finally email IT with everything that transpired.
echo "Student iPad Inventory compliance check has run.  The following happened:" > /tmp/Emailout.txt
echo "==========-----------------------------------****-----------------------------------==========" >> /tmp/Emailout.txt
cat /tmp/StuProcessErrors.txt >> /tmp/Emailout.txt
/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Emailout.txt -t jsmillie@gatewayk12.org,jczyzewski@gatewayk12.org -u "<<iPadCompliance>> Regular Student iPad Compliance Check" -l $LOG -o tls=no > /dev/null 2>&1

#Clear trigger file so we dont run again
rm -Rf $TriggerFileofEmail
