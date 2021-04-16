#!/bin/bash
 
########################
# ByeByeJAMF.sh
#
# JCS 11/6/2019
########################
 
# Variables used by Casper
apiuser="$4" #Username of user with API Computer read GET and Computer Group PUT access
apipass="$5" #Password of user with API Computer read GET and Computer Group PUT access
jssurl="https://mdmipad.gatewayk12.org:8443"


#Get Device Serial
DeviceSerialNumber=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
echo "Device Serial Number is--> $DeviceSerialNumber"

#Take that serial and get the JSS ID
JSS_ID=$(curl -H "Accept: text/xml" -sfku "${apiuser}:${apipass}" "${jssurl}/JSSResource/computers/serialnumber/${DeviceSerialNumber}/subset/general" | /usr/bin/perl -lne 'BEGIN{undef $/} while (/<id>(.*?)<\/id>/sg){print $1}' | head -n 1)



if [ -z "$JSS_ID" ]; then
	echo "No JSS ID appears to have been returned.  Cant continue!"
	exit 1
else

	#Change room field for device so we know it was done.
	/usr/local/bin/jamf recon -room "MIGRATED_to_Mosyle"
	echo "Device JSS ID is: $JSS_ID"
    #Trigger Unmanagement comand through API so any Managed Policies are removed from the machine
    echo ">>>>>>>>>>>>>>> /usr/bin/curl -s -X POST -H "Content-Type: text/xml" -u "${apiuser}:${apipass}" "${jssurl}/JSSResource/computercommands/command/UnmanageDevice/id/${JSS_ID}" <<<<<<<<<<<<<<<<<<"
	/usr/bin/curl -k -s -X POST -H "Content-Type: text/xml" -u "${apiuser}:${apipass}" "${jssurl}/JSSResource/computercommands/command/UnmanageDevice/id/${JSS_ID}"


	#Lets wait 10 seconds..
	sleep 10

	##################
	#  Now we wait a few to make sure the profiles really leave the machine.
	#  if they dont, because they were installed by DEP we wont be able to remove
	#  them without the existing MDM server.
	#################
	#Set our Waiting Counter
	WaitingCount=0
	#Preload the GotProfiles Variable
	GotProfiles="JunkText"

	#Run this loop until we DONT have the JAMF profile installed or we have waited
	#more than a minute for things to change.
	until [ -z "$GotProfiles" ]; do
		GotProfiles=$(profiles list -all | grep 00000000-0000-0000-A000-4A414D460003)
		echo "JAMF Profiles are still here...  WAITING!"
		sleep 5
		let WaitingCount=WaitingCount+1
		
		if [ "$WaitingCount" -ge 12 ]; then
			echo "We've waited a minute for these profiles to disable.  Epic Fail!"
			exit 1
		fi
	done
	
	##################
	# If we are here then JAMF profiles are gone
	# and we can finish up the removal of the frame works.
	##################
    
    #Make note in the JSS this machine is now unmanged.  Otherwise it will appear as Managed
    #even though it can't be controlled anymore!
	computerInfo="<computer><general><remote_management><managed>false</managed></remote_management></general></computer>"
	/usr/bin/curl -k 0 "${jssurl}/JSSResource/computers/serialnumber/$DeviceSerialNumber" --user "${apiuser}:${apipass}" -H "Content-Type: text/xml" -X PUT -d "$computerInfo"
    
	# Removing JAMF MDM Profile
	echo "Removing MDM profile..."
	/usr/local/jamf/bin/jamf removeMdmProfile
	sleep 5
	# Removing JAMF Framework
	echo "Removing JAMF Framework"
	jamf removeframework
	sleep 10
	# Removing user profiles left behind
	echo "Removing other profiles left behind..."
	# Exclude system/default accounts
	SkipUsers='Shared\|_\|nobody\|root\|daemon'
	for username in $(dscl . list /Users | grep -v $SkipUsers)
	do
	identifier="$(/usr/bin/profiles -L -U $username | awk "/attribute/" | awk '{print $4}')"
	echo "Removing profile: $identifier"
	/usr/bin/profiles -R -p "$identifier" -U $username
	done
	sleep 5
	#Check for DEP Enrollment
	/usr/libexec/mdmclient dep nag
	profiles -N
	profiles renew -type enrollment
fi