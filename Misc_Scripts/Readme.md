# What is this?
Just random scripts.  I don't schedule them, they are not run regularly, but they are useful.
* **99.MassiPad2Limbo.sh** -> Takes a list of serials, gets their UDID from Mosyle, and then moves them to Limbo.
* **TestGetClasses.sh** -> Attempt to export a list of class names and the kids who are in them.  I don't remember where I was going with this, but it didn't help
* **byebyeJAMF.sh** -> This is the script I used with JAMF Pro as a policy to migrate all of my Teacher issued Macs to Mosyle.  See below

#Mosyle Migration from JAMFPro
I used this Late Winter 2020 right before CoVID19 changed everything to migrate all of our Macs without reformatting them.  Things to know about our deployment:
* All Macs were enrolled into JAMF Pro with DEP.
* All profiles for MDM were set as CANNOT REMOVE.  
* None of our staff are Administrators on their computers.  
* All Machines running MacOS 10.14.  MacOS 10.15 was also tested and working at the time.

Because of the profiles set as not to allow removal I normally would have to run the __RemoveMDM__ button through JAMF Pro first and then I can do all the other magic to migrate the device.  My script does this (with some waiting to make sure it really happened) and also changes the room name to **MIGRATED_to_Mosyle** to help me keep track of who I've done and where I still have to go.  This script would have been scoped as a policy for all Macs, but not scheduled to run.  Instead it was run manually through Self Service.

**NOTE->** Field 4 and 5 have to be filled in on the JAMF side with a user who has rights to change computer records through the API.

To migrate I would login to each Mac with a local Administrator account, open Self Service, and then run the script.  Wait until prompted then login with the users credentials to the new enrollment prompt.  Reboot, let them log back in as themselves.  Done deal.  Had the users been local Adminsitrators they could have easily done this on their own, but so far we have no real good reason to give out those privledges and plenty to restrict.  





