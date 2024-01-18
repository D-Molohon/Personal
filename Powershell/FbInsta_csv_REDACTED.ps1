## FbInsta_csv.ps1
## Original .sh version made by CZ, .ps1 conversion done by DM
## Created 08/22/2023

## For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 
## SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
####################
# DATE LOGIC       #
####################
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
}
Get-CurrentDate

#########################
# LOGGING               #
#########################
$slack_uri = "REDACTED"
function Update-Slack ([string]$one) {
    Get-CurrentDate
    if ($one -like '*“*' -or $one -like '*”*') {
        $one = $one.replace('“','"').replace('”','"')
    }
    $body = ConvertTo-JSON @{
        text = "$one"
    }
    try {
        Invoke-WebRequest -URI $slack_uri -Method "POST" -Body $body -ContentType 'application/json; charset=UTF-8' | Out-Null
    } catch {
        $body = ConvertTo-JSON @{ text = "Error when attempting to send update via Slack, error is as follows: $($_.Exception)" }
        Invoke-WebRequest -URI $slack_uri -Method "POST" -Body $body -ContentType 'application/json; charset=UTF-8' | Out-Null
    }
}

#########################
# MISC VARIABLES        #
#########################
$baseDir="REDACTED"
$client="REDACTED"
$working_filepath="REDACTED"

#########################
# EGNYTE VARIABLES      #
#########################
$egnyte_scp_loc="/Shared/Projects Drive/$client$working_filepath"
$egnyte_output_fn="$(Get-Date -Format yyyyMMdd)_$($client)_social_leads.csv"

#########################
# GITHUB AUTHORIZATION  #
#########################
Import-Module -Name CredentialManager
$github_token_credential = Get-StoredCredential -Target GitHub
$github_token = $github_token_credential.GetNetworkCredential().password
$github_headers = @{ Authorization = "token $github_token" }

#########################
# CREDENTIALS           #
#########################
$bad_char=[char]0x00
# Grab and format our AES Key to decrypt our tokens and keys
$aeskey=(Invoke-WebRequest -UseBasicParsing -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2)
$aeskey=$aeskey -split ","
$aeskey=$aeskey.replace("$bad_char","")
# Grab the contents from GitHub, which are encrypted, and turn them into a PWSH Secure String using our AES Key.
# Delay needed to handle mutliple requests properly.
$e_rsakey=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_egnyte_sftp=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
# Use the encrypted String in a PSCredential Object...
$rsakey_credential = New-Object System.Management.Automation.PsCredential("Placeholder1", $e_rsakey)
$egnyte_sftp_credential = New-Object System.Management.Automation.PsCredential("Placeholder2", $e_egnyte_sftp)
# Grab the password part of the object we just made, which was decrypted and is stored in the PsCredential Object
$rsakey2 = $rsakey_credential.GetNetworkCredential().password
$egnyte_sftp_pwd = $egnyte_sftp_credential.GetNetworkCredential().password

## Begin the workflow
Update-Slack "$($tCurrentTime) -- Starting workflow"
if (!$(Test-Path "$baseDir\$client")) {
    Update-Slack "$($tCurrentTime) -- Missing client folder, creating..."
    New-Item -ItemType Directory -Path "$baseDir\$client"
    New-Item -ItemType Directory -Path "$baseDir\$client\workDir"
    New-Item -ItemType Directory -Path "$baseDir\$client\workDir\originals"
    Update-Slack "$($tCurrentTime) -- Client folder created."
}
## Copying egnyte_scp_loc to the workDir folder for our $client
Update-Slack "$($tCurrentTime) -- Downloading from Egnyte SFTP with WinSCP."

Get-CurrentDate
$log_date = $(Get-Date -Date $tCurrentTime -Format yyyyMMdd_HHmmss)
& "C:\Program Files (x86)\WinSCP\WinSCP.com" `
  /log="$baseDir\logs\fbinsta_GET_log_$($log_date).txt" /ini=nul `
  /command `
    "open sftp://egnyte_sftp%24REDACTED:$egnyte_sftp_pwd@REDACTED.egnyte.com -hostkey=`"`"$rsakey2`"`"" `
    "cd `"`"$egnyte_scp_loc`"`"" `
    "lcd $baseDir\$client\workDir\originals" `
    "get -delete *.csv" `
    "mkdir `"`"$egnyte_scp_loc/originals/$(Get-Date -Format yyyyMMdd)`"`"" `
    "exit"

$ec=$?
## Confirming drive has mounted. If it hasn't, error out.
if (!$ec) {
    Update-Slack "$($tCurrentTime) -- ERROR: Egnyte SFTP failed to copy. Please investigate."
    exit
}

## If no files, exit.
if (!$(Test-Path "$baseDir$client\workDir\originals\*.csv")) {
    Update-Slack "$($tCurrentTime) -- No files to process today. Exiting."
    exit
}

## Combining all CSVs into one work file
Update-Slack "$($tCurrentTime) -- Combining all CSVs into one work file."
# Make something we can use to store all the lead data in one place.
class User_Lead {
    [string]$date
    [string]$course
    [int]$hs_year
    [string]$email
    [string]$firstname
    [string]$lastname
    [int]$zip
    [string]$phone
}

## For each CSV found, grab the content inside, put it in $new_user, and export that to our consolidated CSV. 
foreach ($csv in $(Get-ChildItem "$baseDir\$client\workDir\originals\*.csv")) {
    $csv_content = Get-Content -Path "$baseDir\$client\workDir\originals\$($csv.Name)"
    $csv_content = $csv_content -split ","
    $new_user = [User_lead]::new()
    $new_user.date = $csv_content[0]
    $new_user.course = $csv_content[1]
    $new_user.hs_year = $csv_content[2]
    $new_user.email = $csv_content[3]
    $new_user.firstname = $csv_content[4]
    $new_user.lastname = $csv_content[5]
    $new_user.zip = $csv_content[6]
    $new_user.phone = $csv_content[7]

    Export-CSV -InputObject $new_user -Path "$baseDir\$client\workDir\$egnyte_output_fn" -Append -NoTypeInformation
}

## Move the files to Egnyte to finish up!
Update-Slack "$($tCurrentTime) -- Uploading to Egnyte SFTP with WinSCP."
Get-CurrentDate
$log_date = $(Get-Date -Date $tCurrentTime -Format yyyyMMdd_HHmmss)
& "C:\Program Files (x86)\WinSCP\WinSCP.com" `
  /log="$baseDir\logs\fbinsta_PUT_log_$($log_date).txt" /ini=nul `
  /command `
    "open sftp://egnyte_sftp%24REDACTED:$egnyte_sftp_pwd@REDACTED.egnyte.com -hostkey=`"`"$rsakey2`"`"" `
    "cd `"`"$egnyte_scp_loc/client consolidated data`"`"" `
    "lcd $baseDir\$client\workDir" `
    "put -delete *.csv" `
    "cd `"`"$egnyte_scp_loc/originals/$(Get-Date -Format yyyyMMdd)`"`"" `
    "lcd $baseDir\$client\workDir\originals" `
    "put -delete *" `
    "exit"

Update-Slack "$($tCurrentTime) -- Workflow complete."