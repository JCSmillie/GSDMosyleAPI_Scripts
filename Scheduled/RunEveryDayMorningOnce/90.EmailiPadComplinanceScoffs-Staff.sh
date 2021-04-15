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
TriggerFileofEmail="/tmp/StaffiPadsOutOFCompliance.txt"
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
        echo "90.EmailiPadComplinanceScoffs.sh ++> $TODAY =====> $LINE" >> $LOG
}

#Query Incident IQ to see device has a tickcet open already
#if it does most likely thats related and we shouldnt make
#a new one.  
IIQ_Lookup() {
	Auth=$(echo "Authorization: Bearer $apitoken")
	Query="$baseurl/assets/serial/$DeviceSerialNumber"

	#Ask IIQ if the serial number applied has tickets open.  Use cut to just get back true or false
	HasTickets=$(curl -s -k -H "$siteid" -H "$Auth" -H "Client: ApiClient" -X GET "$Query" | grep HasOpenTickets | cut -d ':' -f 2 | cut -d ',' -f 1)
	#Hack off white spaces
	HasTickets="${HasTickets//[[:space:]]/}"
}

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
	
	echo "We will email $email about iPad with GSD tag #$AssetTag last seen on $LastSeen"
	
	rm -Rf /tmp/Email1.txt
	rm -Rf /tmp/Email2.txt
	
	#Make the email going to the user
	echo "The iPad assigned to you ($email) with GSD tag #$AssetTag has not checked in for inventory since $LastSeen.  Per GSD Technology Proceedures (see the Incident IQ Knowledge base) all faculty iPads MUST CHECK IN at least every 30 days.  Please ensure at this time your device is charged and on a wifi network.  Try to use it.  If you no longer want the device please make arrangements through the Gator Help Desk to turn it back in.  A ticket has been created for this issue and a Gator Help Desk technican will be in touch to assist you with this matter.  Thank you." > /tmp/Email1.txt
	/usr/local/Smillieware/bin/sendEmail -f jsmillie@gatewayk12.org -s noserver.nodomain.wtf:25 -o message-file=/tmp/Email1.txt -t $email -u "<<iPadCompliance>> Assigned iPad out of Inventory Compliance" -l $LOG -o tls=no > /dev/null 2>&1
	
	#Call ticket lookup function to see if Serial has a ticket open in IncidentIQ
	IIQ_Lookup
	
	
	if [ "$HasTickets" = "true" ]; then
		log_line "A ticket already exists for $DeviceSerialNumber.  No ticket made."
	else
		log_line "No tickets found for $DeviceSerialNumber.  Sending an email to make a ticket."
		#Make the email going to the ticket system
		echo "iPad assigned to user ($email) with GSD tag #$AssetTag has not checked in for inventory since $LastSeen.  Per GSD Technology Proceedures (see the Incident IQ Knowledge base) all faculty iPads MUST CHECK IN at least every 30 days.  Follow up with user and work with them to get iPad back on network and in good standing or turned in." > /tmp/Email2.txt
		/usr/local/Smillieware/bin/sendEmail -f $email -s noserver.nodomain.wtf:25 -o message-file=/tmp/Email2.txt -t helpdesk@gatewayk12.org -u "<<iPadCompliance>> Assigned iPad out of Inventory Compliance" -l $LOG -o tls=no > /dev/null 2>&1
	fi
	

done

#Delete Trigger File so we dont fire off again.
rm -Rf $TriggerFileofEmail