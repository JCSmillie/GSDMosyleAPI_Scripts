#Scheduled Scripts
##Corner Stones
The corner stones of all this work relies on:
* 2.iOS_TagsNUsers.sh
* 2.MacOS_TagsNUsers.sh

Unlike the JAMF API where you ask about a particular machine for data the Mosyle API is queried for ALL data of a type (ios, mac, appletv.)  The scripts above make that query and save them to tab delimited files for future usage by the scripts below.  I do this daily at midnight..  I've thought about doing it twice a day, but haven't gotten a good reason to do so.

##What they Do
All of the scripts here run scheduled on a Mac in my office.  There jobs are:
* Filling in Asset Tags based on Incident IQ Asset tag data
  *iOS\_TagsNAssets.sh  <-iPads
  *80.MacOS\_TagsNAssets.sh <-Macs
  *AppleTV\_TagsNnames.sh  <-AppleTVs
* Adding tags to identify Cyber kids & GATE kids (hybrid cyber thing happening at GSD 2019-2020 school year.)  Adding Outside placement tags so we know how a student is classified.  All of this is done so when a parent calls the help desk for support we have a better idea of where they are without going to the SIS to look them up.
  *50.CyberTagz.sh
  *50.SpecEdOutsidePlacementTagz.sh
* Enabling Lost mode on iPads tagged as Missing in IncidentIQ and adding Lost tags.
  *3.iPadLostTags.sh
* Emailing iPads out of Compliance.  I have groups dynamic groups in Mosyle which build lists based on last time an iPad checked in.  30 days for Staff and Cyber Kids, 21 Days for Teachers, and 7 days for students.  These lists are queried through the API and then parsed to email students, parents, and homeroom teachers.  In the case of Teachers and Staff an email also goes to helpdesk@gatewayk12.org to make a ticket to track the problem.
  *60.TeachersiPadsoutofInventoryComplianceQuery.sh
  *90.EmailiPadComplinanceScoffs-Teachers.sh
  *63.StaffiPadsoutofInventoryComplianceQuery.sh
  *90.EmailiPadComplinanceScoffs-Staff.sh
  *61.StudentsiPadsoutofInventoryComplianceQuery.sh
  *91.EmailiPadComplinanceScoffs-RegStu.sh
  *62.CyberStudentsiPadsoutofInventoryComplianceQuery.sh
  *91.EmailiPadComplinanceScoffs-CYBER.sh
  
##Folders
The folders each item is in represents when the script is scheduled to run.  While this is inconseqencial for the public posting of this code it helps me to remember what needs updated as time allows.

##External programs called
* _/usr/local/Smillieware/bin/sendEmail_ Perl script written by Written by: Brandon Zehm <caspian@dotconf.net> which I use in a ton of places.  Its a quick and dirty way to send some emails to an internally trusted domain server.  https://github.com/mogaal/sendemail
* _/usr/local/bin/slacktee.sh_  Script to send output to a Slack Channel.  https://github.com/coursehero/slacktee

