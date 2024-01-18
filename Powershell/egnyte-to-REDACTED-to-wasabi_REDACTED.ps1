# Filename: egnyte-to-REDACTED-to-wasabi.ps1                              
# Use: Copy files from Egnyte over FTP and delete them.        
# Author: TJB, DM       
#
# Requires: 
# WinSCP .NET Assembly
# Egnyte FTP == Enabled
# SFTP
# Binary Mode & Passive Mode in WinSCP
#
# WinSCP Automation Guide:
# https://winscp.net/eng/docs/guide_automation                                                                                                                                     
# 05/15/2022 - DM:
# - Updated Slack functionality to push updates to a Slack Webhook, the "REDACTED Bot", to post in the REDACTED channel.
# - Posts current process and any found projects in the "Delta_Staging" to be moved to Wasabi
# - Updated Time/Date features
# 05/16/2022 - DM:
# - Changed use of REDACTED to REDACTED
# - Added usage of Secure Password Storage via PowerShell Secure Strings
# 
# TODO:
#
# For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 
# SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#########################
# DATE LOGIC            #
#########################
function Get-CurrentDate () {
  $tDate = (Get-Date).ToUniversalTime()
  try {
      $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")
  } catch 
  {
      #this is the fix for running on Mac's - Windows has the "Eastern Standard Time"
      $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("America/New_York")
  }
  Set-Variable -Name tCurrentTime -Value ([System.TimeZoneInfo]::ConvertTimeFromUtc($tDate, $tz)) -Scope Global
  $tCurrentTime = $tCurrentTime -replace "\n",""
}
Get-CurrentDate

#########################
# LOGGING               #
#########################
$slack_uri = 'REDACTED'
function Update-Slack ([string]$one) {
  $body = ConvertTo-Json @{
      text = "$one"
  }
  Invoke-RestMethod -uri $slack_uri -Method Post -body $body -ContentType 'application/json' | Out-Null
}
$logdate = Get-Date -Date $tCurrentTime -Format "MM_dd_yyyy_hh_mm_ss_tt"

#########################
# GITHUB AUTHORIZATION  #
#########################
$github_token_credential = Get-StoredCredential -Target GitHub
$github_token = $github_token_credential.GetNetworkCredential().password
$github_headers = @{ Authorization = "token $github_token" }

#########################
# CREDENTIALS           #
#########################
$bad_char=[char]0x00
#Grab and format our AES Key to decrypt our tokens and keys
$aeskey=(Invoke-WebRequest -UseBasicParsing -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2)
$aeskey=$aeskey -split ","
$aeskey=$aeskey.replace("$bad_char","")
# Grab the contents from GitHub, which are encrypted, and turn them into a PWSH Secure String using our AES Key.
# Delay needed to handle mutliple requests properly.
$e_rsakey=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_REDACTED=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_wasabi_archive=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
# Use the encrypted String in a PSCredential Object...
$rsakey_credential = New-Object System.Management.Automation.PsCredential("Placeholder1", $e_rsakey)
$egnyte_credential = New-Object System.Management.Automation.PsCredential("Placeholder2", $e_REDACTED)
$wasabi_credential = New-Object System.Management.Automation.PsCredential("Placeholder3", $e_wasabi_archive)
# Grab the password part of the object we just made, which was decrypted and is stored in the PsCredential Object
$rsakey = $rsakey_credential.GetNetworkCredential().password
$REDACTED_pwd = $egnyte_credential.GetNetworkCredential().password
$wasabi_archive_pwd = $wasabi_credential.GetNetworkCredential().password

########################
# DECLARE SYNC START   #
########################
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Starting Wasabi archiving, Timestamp: $cDateTime"

########################
# FOLDER CREATION      #
########################
New-Item "D:\_EGNYTE\Delta_Staging\" -ItemType Directory -Name "_PROJECTS"
New-Item "D:\_EGNYTE\Delta_Staging\" -ItemType Directory -Name "_MODULES"

######################
# Start WinSCP       #
# Start a log        #
# Connect to Egnyte  #
# Copy to REDACTED #
# Delete from Egnyte #
######################  
& "C:\Program Files (x86)\WinSCP\WinSCP.com" `
  /log="C:\REDACTED\logs\winscp_download_delete logs\WinSCP-egnyte-$logdate.log" /ini=nul `
  /command `
    "open sftp://REDACTED%24REDACTED:$REDACTED_pwd@ftp-REDACTED.egnyte.com/ -hostkey=`"$rsakey`"" `
    "cd `"`"/Shared/staging/_PROJECTS`"`"" `
    "lcd D:\_EGNYTE\Delta_Staging\_PROJECTS" `
    "get -delete *" `
    "exit" | Tee-Object -Variable winscp_egnyte_projects_stdout

foreach ($line in $winscp_egnyte_projects_stdout) {
  Update-Slack "$line"
  Start-Sleep -M .250 # Slack burst limit for webhooks is higher than this, but this works
}

$egnyte_winscpResult = $?
$script_error=$Error[-0]
if ($egnyte_winscpResult -eq "True") {
  Update-Slack "WinSCP Successfully transferred PROJECTS from Egnyte to REDACTED"
} elseif (!$egnyte_winscpResult -eq "True") {
  Update-Slack "Error: The Egnyte Evacuation script has failed when copying PROJECTS over FTP from Egnyte to REDACTED.
Egnyte FTP error: $script_error" 
  Get-CurrentDate
  Update-Slack "Stopping Wasabi archiving, Timestamp: $tCurrentTime"
  exit
}

# Report files in "_EGNYTE\Delta_Staging" that will be moved to Wasabi
Set-Location "D:\_EGNYTE\Delta_Staging"
Get-ChildItem .\_PROJECTS\*\Projects\* | ForEach-Object {Update-Slack "Found Item: $_"}
#Delta_Staging\_PROJECTS\ANY_CLIENT\Projects\ALL_FILES

# Copy the data from delta_staging to the actual local directory 
Set-Location "D:\_EGNYTE\Delta_Staging"
# $exclude = Get-ChildItem -recurse "D:\_EGNYTE\Shared\Projects Archive"
Copy-Item ".\_PROJECTS\*" -Destination "D:\_EGNYTE\Shared\Projects Archive" -recurse -verbose #-Exclude $exclude

$localXferResult = $?
$script_error=$Error[-0]
if ($localXferResult -eq "True") {
  Update-Slack "Local Transfer Success from Delta_Staging to _EGNYTE Projects Archive"
} elseif (!$localXferResult -eq "True") {
  Update-Slack "Error: The Egnyte Evacuation script had an error when copying locally from Delta_Staging to Wasabi.
Local Xfer Error: $script_error
Proceeding..."
}

######################
# Start WinSCP       #
# Start a log        #
# Connect to Egnyte  #
# Sync Modules       #
# Delete from Egnyte #
######################  
& "C:\Program Files (x86)\WinSCP\WinSCP.com" `
  /log="C:\REDACTED\logs\winscp_download_delete logs\WinSCP-egnyte-$logdate.log" /ini=nul `
  /command `
    "open sftp://REDACTED%24REDACTED:$REDACTED_pwd@REDACTED.egnyte.com/ -hostkey=`"$rsakey`"" `
    "synchronize local `"`"D:\_EGNYTE\_ALL MODULES backup`"`" `"`"/Shared/staging/_MODULES`"`"" `
    "exit" | Tee-Object -Variable winscp_modules_sync_stdout

foreach ($line in $winscp_modules_sync_stdout) {
  Update-Slack "$line"
  Start-Sleep -M .250
}

$egnyte_winscpResult = $?
$script_error=$Error[-0]
if ($egnyte_winscpResult -eq "True") {
  Update-Slack "WinSCP Successfully synced MODULES from Egnyte to REDACTED"
} elseif (!$egnyte_winscpResult -eq "True") {
  Update-Slack "Error: The Egnyte Evacuation script has failed when copying over FTP from Egnyte to REDACTED.
Egnyte FTP error: $script_error" 
  Get-CurrentDate
  Update-Slack "Stopping Wasabi archiving, Timestamp: $tCurrentTime"
  exit
}

###########################
# Start WinSCP            #
# Start a log             #
# Connect to Wasabi       #
# Copy from _PROJECTS     #
# Put into Wasabi         #
########################### 
& "C:\Program Files (x86)\WinSCP\WinSCP.com" `
  /log="C:\REDACTED\logs\winscp_download_delete logs\WinSCP_wasabi-$logdate.log" /ini=nul `
  /command `
    "open ftp://wasabiarchive%40REDACTED:$wasabi_archive_pwd@REDACTED.wasabisys.com/ -rawsettings ProxyPort=0" `
    "lcd `"`"D:\_EGNYTE\Delta_Staging\_PROJECTS`"`"" `
    "cd `"`"/REDACTED-egnytearchive/Cold Storage Placeholder/Shared/Projects Archive`"`"" `
    "put *" `
    "exit" | Tee-Object -Variable winscp_projects_wasabi_stdout

foreach ($line in $winscp_projects_wasabi_stdout) {
  Update-Slack "$line"
  Start-Sleep -M .250
}
 
$wasabi_winscpResult = $?
$script_error=$Error[-0]
if ($wasabi_winscpResult -eq "True") {
  Update-Slack "WinSCP Successfully transferred from REDACTED Projects to Wasabi"
} elseif (!$wasabi_winscpResult -eq "True") {
  Update-Slack "Error: The Egnyte Evacuation script has failed when copying over FTP from REDACTED to Wasabi regarding Projects.
Wasabi FTP error: $script_error" 
  Get-CurrentDate
  Update-Slack "Stopping Wasabi PROJECTS archiving, Timestamp: $tCurrentTime"
  exit
}

###########################
# Start WinSCP            #
# Start a log             #
# Connect to Wasabi       #
# Sync MODULES            #
# Put into Wasabi         #
########################### 
if (Test-Path "D:\_EGNYTE\Delta_Staging\_MODULES") {
  & "C:\Program Files (x86)\WinSCP\WinSCP.com" `
    /log="C:\REDACTED\logs\winscp_download_delete logs\WinSCP_wasabi-$logdate.log" /ini=nul `
    /command `
      "open ftp://wasabiarchive%40REDACTED:$wasabi_archive_pwd@REDACTED.wasabisys.com/ -rawsettings ProxyPort=0" `
      "synchronize remote -mirror `"`"D:\_EGNYTE\_ALL MODULES backup`"`" `"`"/REDACTED-egnytearchive/Cold Storage Placeholder/Shared/_ALL MODULES backup`"`"" `
      "exit" | Tee-Object -Variable winscp_modules_wasabi_stdout
    
  foreach ($line in $winscp_modules_wasabi_stdout) {
    Update-Slack "$line"
    Start-Sleep -M .250
  }
    
  $wasabi_winscpResult = $?
  $script_error=$Error[-0]
  if ($wasabi_winscpResult -eq "True") {
    Update-Slack "WinSCP Successfully transferred from REDACTED Modules to Wasabi"
  } elseif (!$wasabi_winscpResult -eq "True") {
    Update-Slack "Error: The Egnyte Evacuation script has failed when copying over FTP from REDACTED to Wasabi regarding Modules.
Wasabi FTP error: $script_error" 
    Get-CurrentDate
    Update-Slack "Stopping Wasabi MODULES archiving, Timestamp: $tCurrentTime"
    exit
  }
}

# Clear out the delta_staging folder
Set-Location "D:\_EGNYTE\Delta_Staging"
Get-ChildItem -Recurse | Remove-Item -recurse -verbose

$localDeleteResult = $?
$script_error=$Error[-0]
if ($localDeleteResult -eq "True") {
  Update-Slack "Local Clear Success of folder Delta_Staging"
} elseif (!$localDeleteResult -eq "True") {
  Update-Slack "Error: The Egnyte Evacuation script has failed when clearing the Delta_Staging Folder.
Local Clearing error: $script_error"
  Get-CurrentDate
  Update-Slack "Stopping Wasabi archiving, Timestamp: $tCurrentTime"
  exit
}

Get-CurrentDate
Update-Slack "Stopping Wasabi archiving, Timestamp: $tCurrentTime"