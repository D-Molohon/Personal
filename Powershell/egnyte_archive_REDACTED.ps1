#################################################################
#
#                                                       
# Filename: egnyte_archive_v3.0.ps1                              
# Use: Egnyte Move to Archive Script        
# Author: TJB, CZ, DM       
# Requires: 
# Powershell 5.1 Compliance
# WMJ API Guide:
# https://support.workamajig.com/hc/en-us/articles/360023007451-API-Overview
# Egnyte API Guide:
# https://developers.egnyte.com/docs
#                                                                                                                         
#                 
# 05/11/2023 - DM - Added Update-Slack function to Egnyte Archive, posting to #it-egnyte-archive private Slack channel.   
# Also sifted through the script, giving it similar navigation to the Egnyte Sync Script.
# 05/16/2023 - DM - Reconfigured script to utilize encrypted tokens/credentials.
# - Added 2020reportapikey from the Egnyte Sync due to WMJ Report limit of 10k projects.
# 06/26/2023 - DM - Since the last couple of changes, a lot of this has been reworked
# - Added multiple functions
# - Added Request-URL for handling/reporting of errors when interacting with projects
# - Added the WMJ_Project class and its properties, integrating the old method of variable handling into an object
# - Tuned script in favor of accuracy and error checking/catching/logging
#################################################################

#################################################################
# COMMON ISSUES AREA                                            #
#################################################################
#
# If Slack says there was API error, check the Projects Drive and Archive folders for a /CLIENT/Projects folder
#
#################################################################

# To use "[List[string]]$project_team_original = [List[string]]::new()" in the WMJ_Project class, this needs to be the first line of the script and enabled use of a string list
using namespace System.Collections.Generic
# For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 
# SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module -Name CredentialManager

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
}
Get-CurrentDate

#########################
# URL ENCODING RESERVED CHARACTERS #
#########################
$url_table = @{
    '!' = '%21'
    '"' = '%22'
    '#' = '%23'
    '$' = '%24'
    '%' = '%25'
    '&' = '%26'
    "'" = '%27'
    "(" = '%28'
    ")" = '%29'
    '*' = '%2A'
    '+' = '%2B'
    ',' = '%2C'
    '/' = '%2F'
    ':' = '%3A'
    ';' = '%3B'
    '=' = '%3D'
    '?' = '%3F'
    '@' = '%40'
    '[' = '%5B'
    ']' = '%5D'
}
$url_chars = $url_table.Keys
# Adding Powershell Unicode formatting
$open_quote = "\u201C" 
$closed_quote = "\u201D"
#########################
# API FUNCTION          #
#########################
# We had to integrate the older script into a more adaptable version with Invoke-WebRequest instead of Invoke-RestMethod.
# We also had to implement try/catch support in case of a failure when attempting to make an API request.
New-Variable -Scope Global -Name response
New-Variable -Scope Global -Name url_response
function Request-URL ($U, $M, $B, $H, $label) {
    if ($B -notlike "N/A") {
        try {$B | ConvertFrom-JSON | Out-Null} catch {Write-Output "Body is NOT in JSON format."; throw}
    }
    if ($project.id) {
        $U_test = $U.ToCharArray()
        foreach ($char in $U_test) {
            if ($url_chars -contains $char) {
                $U_index = $U.IndexOf("$char")
                if ($U_index -le 78) { continue } # the Index of 78 is the '/' after Projects when using a Projects Drive link
                $U_replaceval = $url_table["$char"]
                $U = $U.remove($U_index,1).insert($U_index,$U_replaceval)
            }
        }
    }
    if ("$M" -like "*POST*" -or "$M" -like "*DELETE*") {
        if ($H) {
            try {
                $global:response=Invoke-WebRequest -URI $U -Method $M -Body $B -Headers $H -ContentType 'application/json; charset=UTF-8'
                $global:url_response = $global:response.Content | ConvertFrom-JSON
            } catch {
                Update-Slack "Issue detected when attempting API POST or DELETE interaction at $label"
                if ($project) {
                    $project.post_successful = $False
                    $project.post_error = Write-Output $_.Exception
                    $project.post_attempt = "URI: $U METHOD: $M BODY: $B HEADERS: $H LABEL: $label"
                    $global:project_error = 1
                }
                Write-Output "HERE'S WHAT WAS ATTEMPTED: $U $M $B $H $label $($_.Exception)"
            }
        } else {
            try {
                $global:response=Invoke-WebRequest -URI $U -Method $M -Body $B -ContentType 'application/json; charset=UTF-8'
                $global:url_response = $global:response.Content | ConvertFrom-JSON
            } catch {
                Update-Slack "Issue detected when attempting API POST or DELETE interaction at $label"
                if ($project) {
                    $project.post_successful = $False
                    $project.post_error = Write-Output $_.Exception
                    $project.post_attempt = "URI: $U METHOD: $M BODY: $B LABEL: $label"
                    $global:project_error = 1
                }
                Write-Output "HERE'S WHAT WAS ATTEMPTED: $U $M $B $label $($_.Exception)"
            }
        }
    } elseif ("$M" -like "*GET*") {
        if ($B -like "*n/a*") {Remove-Variable B}
        try {
            $global:response=Invoke-WebRequest -URI $U -Method $M -Headers $H -ContentType 'application/json; charset=UTF-8'
            try {$global:url_response = $global:response.Content | ConvertFrom-JSON} catch {Write-Host "Non-JSON Body from GET request."}
        } catch {
            Update-Slack "Issue detected when attempting API GET interaction at $label"
            if ($project.id) {
                $project.post_successful = $False
                $project.post_error = Write-Output $_.Exception
                $project.post_attempt = "URI: $U METHOD: $M HEADERS: $H LABEL: $label"
                $global:project_error = 1
            }
            Write-Output "HERE'S WHAT WAS ATTEMPTED: $U $M $H $label $($_.Exception)"
        }
    }
}

#########################
# LOGGING               #
#########################
$slack_uri = 'REDACTED'
function Update-Slack ([string]$one) {
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
$e_wmj_apikey=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_wmj_usertoken=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_wmj_reportapikey=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_wmj_2020reportapikey=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_egnyte_accesstoken=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
# Use the encrypted String in a PSCredential Object...
$wmj_apikey_credential = New-Object System.Management.Automation.PsCredential("placeholder1", $e_wmj_apikey)
$wmj_usertoken_credential = New-Object System.Management.Automation.PsCredential("placeholder2", $e_wmj_usertoken)
$wmj_report_credential = New-Object System.Management.Automation.PsCredential("placeholder3", $e_wmj_reportapikey)
$wmj_2020report_credential = New-Object System.Management.Automation.PsCredential("placeholder4", $e_wmj_2020reportapikey)
$egnyte_accesstoken_credential = New-Object System.Management.Automation.PsCredential("placeholder5", $e_egnyte_accesstoken)
# Grab the password part of the object we just made, which was decrypted and is stored in the PsCredential Object
$wmj_apikey = $wmj_apikey_credential.GetNetworkCredential().password
$wmj_usertoken = $wmj_usertoken_credential.GetNetworkCredential().password
$wmj_reportapikey = $wmj_report_credential.GetNetworkCredential().password
$wmj_2020reportapikey = $wmj_2020report_credential.GetNetworkCredential().password
$egnyte_accesstoken = $egnyte_accesstoken_credential.GetNetworkCredential().password

#########################
# WMJ VARIABLES         #
#########################
$wmj_endpoint = "REDACTED"
$wmj_2020endpoint = "REDACTED"
$wmj_headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$wmj_headers.Add("APIAccessToken", $wmj_apikey)
$wmj_headers.Add("UserToken", $wmj_usertoken)

#########################
# EGNYTE VARIABLES      #
#########################
$egnyte_headers = @{ Authorization = "Bearer $egnyte_accesstoken" }
$egnyte_contractors="REDACTED"
$egnyte_interns="REDACTED"
$egnyte_freelancers="REDACTED"

#########################
# MISC VARIABLES        #
#########################
$curyear = Get-Date -format %y 
$prevyear = ($curyear-1)

########################
# DECLARE SYNC START   #
########################
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Starting Egnyte archiving, Timestamp: $cDateTime"

########################
# WMJ API ACTIONS      #
######################## 
Request-URL "REDACTED" GET "N/A" $wmj_headers "WMJ Status Check" | Out-Null
if ($response.StatusCode -eq 200) {
    Update-Slack "WMJ Status code is $($response.StatusCode). Updating last run time..."
} elseif (!$response.StatusCode -eq 200) {
    Write-Output $response.StatusCode
    Update-Slack "Unable to get Status Code of 200 from WMJ. Exiting Script and retrying."
    exit 1
}

## Flag update
$flagDt=(Get-ChildItem "REDACTED").LastWriteTime
Remove-Item "REDACTED"
New-Item "REDACTED"
Update-Slack "Projects Archiving last ran at: $flagDt"

## WMJ Request over API
# Getting full report data from the 2010s and 2020s reports and loading into an array
Update-Slack "Pulling the WMJ report..."
Start-Sleep -Seconds 1
$wmj_request = @() 
Start-Sleep -Seconds 1
Request-URL $wmj_endpoint GET "N/A" $wmj_headers "WMJ Request #1"
$wmj_request += $url_response.data.report
Start-Sleep -Seconds 1
Request-URL $wmj_2020endpoint GET "N/A" $wmj_headers "WMJ Request #2"
$wmj_request += $url_response.data.report
Start-Sleep -Seconds 1

# Get a list of projects updated in the past 25 hours
# This should really be 48-72 hours due to the need to purge older files, and move items to Wasabi
# Three separate interactions, archive, delete the folder in Projects Drive that's empty, and the move to the staging folder
# 48 hours might be sufficient, but 72 would ensure that multiple actions have the time needed for each project.
$wmj_total_projects = $wmj_request.length
$wmj_response = $wmj_request | Where-Object {(Get-Date $_.date_Updated) -gt (Get-Date -Date $tCurrentTime.AddDays(-3))} | Sort-Object -Property date_updated -Descending
if ($wmj_response.length) {
    $wmj_response_total_projects = $wmj_response.length
} elseif (!$wmj_response.length -And $wmj_response) {
    $wmj_response_total_projects = 1
} else {
    $wmj_response_total_projects = 0
}
Update-Slack "WMJ Report pulled, we have...
Total amount of projects in WMJ: $wmj_total_projects
Total amount of projects to work on right now: $wmj_response_total_projects"

########################
# EGNYTE API ACTIONS   #
########################
#check egnyte API status
Request-URL "REDACTED" GET "N/A" $egnyte_headers "Egnyte Status Check"
if ($response.StatusCode -ne 200) {
    Update-Slack "EGNYTE API CHECK FAILED, STATUS CODE: $($response.StatusCode)"
    Get-CurrentDate
    $cDateTime = Get-Date -Date $tCurrentTime
    $cDateTime = $cDateTime -replace "\n",""
    Update-Slack "Stopping archiving, Timestamp: $cDateTime"
    exit
} elseif ($response.StatusCode -eq 200) {
    Update-Slack "Egnyte API Check Completed, Status Code: $($response.StatusCode), proceeding... "
}
## Getting Egnyte User Information
Start-Sleep -Seconds 2
#get a list of users from egnyte to reference
$egnyte_userlist = @() 
Request-URL "REDACTED" GET "N/A" $egnyte_headers "Egnyte User List Request #1"
$egnyte_userlist += $url_response
Start-Sleep -Seconds 2
Request-URL "REDACTED" GET "N/A" $egnyte_headers "Egnyte User List Request #2"
$egnyte_userlist += $url_response
Start-Sleep -Seconds 2
Request-URL "REDACTED" GET "N/A" $egnyte_headers "Egnyte User List Request #3"
$egnyte_userlist += $url_response
Start-Sleep -Seconds 2
Request-URL "REDACTED" GET "N/A" $egnyte_headers "Egnyte User List Request #4"
$egnyte_userlist += $url_response
Start-Sleep -Seconds 2
Request-URL "REDACTED" GET "N/A" $egnyte_headers "Egnyte User List Request #5"
$egnyte_userlist += $url_response
Start-Sleep -Seconds 2

$egnyte_groupeduserlist = @()
Request-URL "$egnyte_contractors" GET "N/A" $egnyte_headers "Egnyte User List Request - Contractors"
$egnyte_groupeduserlist += $url_response
Start-Sleep -Seconds 2
Request-URL "$egnyte_interns" GET "N/A" $egnyte_headers "Egnyte User List Request - Interns"
$egnyte_groupeduserlist += $url_response
Start-Sleep -Seconds 2
Request-URL "$egnyte_freelancers" GET "N/A" $egnyte_headers "Egnyte User List Request - Freelancers"
$egnyte_groupeduserlist += $url_response

$egnyte_exclusions = @()
#Admin Exclusion
$egnyte_exclusions += $egnyte_userlist.resources | Where-Object { $_.usertype -like "admin" } | ForEach-Object { $_.username }
#Freelancer, Contractor, and Intern Exclusions
$egnyte_exclusions += $egnyte_groupeduserlist.members.username

#######################
# FILECOUNT FUNCTION  #
#######################
function Get-EgnyteFilecount ([string]$folder) {
    $egnyte_folderstats_uri = $folder
    Request-URL $egnyte_folderstats_uri GET "N/A" $egnyte_headers "Egnyte Filecount - Folderstats GET"
    ## This is for Egnyte rate limiting due to Developer QPS
    Start-Sleep -Seconds 2
    $egnyte_filestats_uri = "REDACTED" + $url_response.folder_id + "REDACTED"
    Request-URL $egnyte_filestats_uri GET "N/A" $egnyte_headers "Egnyte Filecount - Filecount GET"
    ## This is for Egnyte rate limiting due to Developer QPS
    Start-Sleep -Seconds 2
    Set-Variable -Name egnyte_filestats_response -Value "" -Scope Global
    $global:egnyte_filestats_response = $url_response.filescount
}

#######################
# PURGE FOLDER FUNCTION #
#######################
function Remove-EgnyteFolder ([string]$folder) {
    Update-Slack "Deleting: $folder"
    Request-URL $folder DELETE "N/A" $egnyte_headers "Egnyte Purge - Delete Folder Request"
    ## This is for Egnyte rate limiting due to Developer QPS
    Start-Sleep -Seconds 2
}

#######################
# PERMISSION SYNC + ARCHIVE #
#######################
# WMJ_Project class allows more optimized forms of centralized data movement/clearing + entry per project
# Default POST status for Invoke-RestMethod is True, unless otherwise declared $False, like a failure to POST
class WMJ_Project {
    [int]$id
    [string]$client_name
    [string]$client_code
    [string]$project_number
    [string]$project_name
    [boolean]$project_active 
    [string]$project_members
    [string]$project_folder
    [string]$egnyte_foundfolder
    [boolean]$post_successful = $True
    [string]$post_error = "N/A"
    [string]$post_attempt
    [string]$reporting_aesthetic_break # Purely a spacer for the formatting of the CSV to be ~aesthetically pleasing~ and leaving the odd fields off to the far side when exported
    [List[string]]$project_team_original = [List[string]]::new()
    [PSCustomObject]$egnyte_projectfolders_response
    [PSCustomObject]$egnyte_archivefolders_response
    [array]$egnyte_projectfolders = @()
    [string]$egnyte_api_interaction
    [System.Collections.Specialized.OrderedDictionary]$egnyte_permissions_array = [ordered]@{}
}
$iteration = 0

# this is the MEAT of this whole operation, this foreach loop is EVERY project in the report pulled from WMJ, matching our criteria (Current DateTime stamp -1 day)
foreach ($wmj_project in $wmj_response) {
    # Start the iteration at 0 out of the loop, +1 each project so we can ID the interaction order and generate some form of progress during the archiving to see how far in the script is.
    $iteration = $iteration + 1
    # Clear the $projectfolder variable, more as a formality than anything.
    if ($projectfolder) {Clear-Variable -name projectfolder}
    # Singular Project declaration, appended to a CSV reporting file at the end
    # $project variable will be removed at the end after being appended to the report, to make room for a new $project.
    $project = [WMJ_Project]::new()
    $project.id = $iteration
    $project.client_name = $wmj_project.Project_Number | Select-String -Pattern '-\w+-' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | ForEach-Object {$_.Trim() -replace '-',''}
    $project.client_code = $wmj_project.Project_Number | ForEach-Object { $_.Replace($project.client_name,'') } | Out-String | ForEach-Object {$_.Trim() -replace '-',''} | ForEach-Object {$_.Trim() -replace '[\s]',''}
    $project.project_number = $wmj_project.Project_Number
    $project.project_name = $wmj_project.Project_Name -replace '[\\/:*?\"<>"(){}|#]',''
    $project.project_active = if ($wmj_project.Project_Status -like "*Project is Complete*") {$False} elseif ($wmj_project.Project_Status -like "*Canceled*") {$False} else {$True}
    $wmj_projectteam_original = $wmj_project.Project_Team -replace "\(\w*\s*\w*\)", "" -split "," | ForEach-Object {$_.Trim()} | Sort-Object -Unique
    foreach ($member in $wmj_projectteam_original) {$project.project_team_original.Add($member)}
    $project.project_members = $project.project_team_original -join ", "
    $project.project_folder = $project.client_code + " - " + $project.project_name
    
    Update-Slack "Checking: $($project.project_number), $iteration/$wmj_response_total_projects"

    #set uri for rest method 
    $egnyte_projects_toplevel_uri = "REDACTED" + $project.client_name + "/Projects"

    #naptime - egnyte rate limiting
    Start-Sleep -Seconds 2

    #set uri for rest method - archive
    $egnyte_archive_toplevel_uri = "REDACTED" + $project.client_name + "/Projects"

    #set uri for rest method - staging
    $egnyte_staging_toplevel_uri = "REDACTED" + $project.client_name + "/Projects"

    #ask every folder what it has in it
    Request-URL $egnyte_projects_toplevel_uri GET "N/A" $egnyte_headers "Project Folders Response"
    if ($project_error -eq 1) {
        $project.egnyte_projectfolders_response = ""
        Update-Slack "Client folder may not exist in Project Drive. If this is the case, please disregard the detected issue."
        $project.post_error = "CLIENT FOLDER MISSING FROM PROJECT Drive: $($project.post_error)"
        $global:project_error = 0
    } else {
        $project.egnyte_projectfolders_response = $url_response
    }
    Start-Sleep -Seconds 2

    #This will error if archive dir not present
    Request-URL $egnyte_archive_toplevel_uri GET "N/A" $egnyte_headers "Project Archive Response"
    if ($project_error -eq 1) {
        $project.egnyte_archivefolders_response = ""
        Update-Slack "Client folder may not exist in Project Archive. If this is the case, please disregard the detected issue."
        $project.post_error = "CLIENT FOLDER MISSING FROM PROJECT ARCHIVE: $($project.post_error)"
        $global:project_error = 0
    } else {
        $project.egnyte_archivefolders_response = $url_response
    }

    #put these results in the array
    $project.egnyte_projectfolders = $project.egnyte_projectfolders_response.folders
    $project.egnyte_projectfolders += $project.egnyte_archivefolders_response.folders
    Start-Sleep -Seconds 2

    # logic to find client code in folder path -- needs to add slack thingy later
    $project.egnyte_foundfolder = $project.egnyte_projectfolders.Path | Where-Object { $_ -like "*/Projects/$($project.client_code)*" }
	
    # checking for multiple folders in $project.egnyte_foundfolder
    if ($project.egnyte_foundfolder -like "*Projects Drive*" -And $project.egnyte_foundfolder -like "*Projects Archive*") {
        Update-Slack "Duplicate folder detected, checking Project Statuses and filecount..."
        $split_egnyte_foundfolder = $project.egnyte_foundfolder -split "/Shared/Projects "
        $split_egnyte_folders = @()
        foreach ($splitfolder in $split_egnyte_foundfolder) {
            if ($splitfolder -match "[a-z]") {
                $split_egnyte_folders += $splitfolder
            }
        }
        $projectdrive_egnyte_foundfolder = "/Shared/Projects " + $split_egnyte_folders[0]
        $projectdrive_egnyte_foundfolder_url = "REDACTED " + $split_egnyte_folders[0]
        $projectarchive_egnyte_foundfolder = "/Shared/Projects " + $split_egnyte_folders[1]
        $projectarchive_egnyte_foundfolder_url = "REDACTED " + $split_egnyte_folders[1]

        # If our current project is active...
        if ($project.project_active) {
            Update-Slack "Project Status is Active, checking Projects Drive..."
            Get-EgnyteFilecount $projectdrive_egnyte_foundfolder_url
            # If the Project folder in the Projects Drive is empty...
            if ($global:egnyte_filestats_response -eq 0) {
                Update-Slack "Projects Drive Folder is empty. Checking Archive folder..."
                Get-EgnyteFilecount $projectarchive_egnyte_foundfolder_url
                # Check our Archived Folder, and if it's empty...
                if ($global:egnyte_filestats_response -eq 0) {
                    # Clear the duplicate Archived folder and set our true folder to the Projects Drive one.
                    Update-Slack "Archived Folder is empty as well? Since Status is Active, deleting the Archived Folder."
                    Remove-EgnyteFolder $projectarchive_egnyte_foundfolder_url
                    $project.egnyte_foundfolder = $projectdrive_egnyte_foundfolder
                # And if it's not empty...
                } elseif ($global:egnyte_filestats_response -gt 0) {
                    Update-Slack "Archived Folder is not empty, while Projects Folder is. Since Project Status is active, moving files from Archive to Project Drive instead."
                    # Move Project Folder contents from Archive folder into Projects Drive folder
                    $project.egnyte_api_interaction = @{
                        action='move'
                        destination="$projectdrive_egnyte_foundfolder_url"
                    } | ConvertTo-JSON
                    Request-URL "$projectarchive_egnyte_foundfolder_url" POST $project.egnyte_api_interaction $egnyte_headers "Duplicate - Move folder from Archive to Projects Drive"
                    ## This is for Egnyte rate limiting due to Developer QPS
                    Start-Sleep -Seconds 2
                    # Clear Archive folder afterwards
                    Remove-EgnyteFolder $projectarchive_egnyte_foundfolder_url
                    # Set the true folder to our Projects Drive one
                    $project.egnyte_foundfolder = $projectdrive_egnyte_foundfolder
                }
            # Meaning our ACTIVE project is not Empty in the Projects Drive
            } elseif ($global:egnyte_filestats_response -gt 0) {
                Update-Slack "Project Drive folder is not empty, evaluating Project Archive folder..."
                # Check to see if our Archive Folder has files, possibly stopped transferring midway?
                Get-EgnyteFilecount $projectarchive_egnyte_foundfolder_url
                if ($global:egnyte_filestats_response -eq 0) {
                    # If it's empty remove it from the Archive.
                    Update-Slack "Active Project Folder has files, Archive folder is empty. Removing..."
                    Remove-EgnyteFolder $projectarchive_egnyte_foundfolder_url
                    $project.egnyte_foundfolder = $projectdrive_egnyte_foundfolder
                } elseif ($global:egnyte_filestats_response -gt 0) {
                    # If it has files, we need to manually evaluate this folder.
                    Update-Slack "!!! DUPLICATE FOUND !!! 
BOTH Project Drive and Archive Project Folders have files for this Active project. Please evaluate these folders: $($project.egnyte_foundfolder)"
                    $project.post_successful = $False
                    $project.post_error = "DUPLICATE FOUND - $($project.egnyte_foundfolder)"
                    $project.egnyte_foundfolder = ""
                }
            }
        }
        # If our current project is inactive...
        if ($project.project_active -eq $False) {
            Update-Slack "Project Status is Inactive, checking Projects Archive..."
            Get-EgnyteFilecount $projectarchive_egnyte_foundfolder_url
            # If the Project folder in the Projects Archive is empty...
            if ($global:egnyte_filestats_response -eq 0) {
                Update-Slack "Archive Folder is empty. Checking Projects Drive folder..."
                Get-EgnyteFilecount $projectdrive_egnyte_foundfolder_url
                # Check our Active Folder...
                if ($global:egnyte_filestats_response -eq 0) {
                    Update-Slack "Projects Drive Folder is empty as well? Since Status is Inactive, deleting the Projects Drive Folder."
                    Remove-EgnyteFolder $projectdrive_egnyte_foundfolder_url
                    $project.egnyte_foundfolder = $projectarchive_egnyte_foundfolder
                # And if it's not empty...
                } elseif ($global:egnyte_filestats_response -gt 0) {
                    Update-Slack "Projects Drive Folder is not empty, while the Archive Folder is. Since Project Status is inactive, this will be archived automatically. Clearing Archive folder..."
                    Remove-EgnyteFolder $projectarchive_egnyte_foundfolder_url
                    # Set the true folder to our Projects Drive one
                    $project.egnyte_foundfolder = $projectdrive_egnyte_foundfolder
                }
            # Meaning our INACTIVE project is not Empty in the Projects Archive
            } elseif ($global:egnyte_filestats_response -gt 0) {
                Update-Slack "Project Archive Folder is not empty, evaluating Project Drive folder..."
                Get-EgnyteFilecount $projectdrive_egnyte_foundfolder_url
                if ($global:egnyte_filestats_response -eq 0) {
                    # If our Project Drive folder is Empty, clear it and set our Archive folder as the true folder.
                    Update-Slack "Project Drive folder is empty, clearing and setting Archive Folder as the current folder."
                    Remove-EgnyteFolder $projectdrive_egnyte_foundfolder_url
                    $project.egnyte_foundfolder = $projectarchive_egnyte_foundfolder
                } elseif ($global:egnyte_filestats_response -gt 0) {
                    # If both folders have content, require manual evaluation.
                    Update-Slack "!!! DUPLICATE FOUND !!! 
BOTH Project Drive and Archive Project Folders have files for this Inactive project. Please evaluate these folders: $($project.egnyte_foundfolder)"
                    $project.post_successful = $False
                    $project.post_error = "DUPLICATE FOUND - $($project.egnyte_foundfolder)"
                    $project.egnyte_foundfolder = ""
                }
            }
        }
    }

    ## Now we shall begin the sacred act of archiving
    if($project.egnyte_foundfolder) {
        Update-Slack "Folder is: $($project.egnyte_foundfolder)"
        Update-Slack "Project is: $(if ($project.project_active) {"Active"} else {"Inactive"})"
        ## Lets make some requests to get the file count -- if there are no files, just delete the folder. 
        $egnyte_folderstats_uri = "REDACTED" + $project.egnyte_foundfolder

        Request-URL $egnyte_folderstats_uri GET "N/A" $egnyte_headers "Egnyte Found Folder - Folderstats GET"
        ## This is for Egnyte rate limiting due to Developer QPS
        Start-Sleep -Seconds 2

        $egnyte_filestats_uri = "REDACTED" + $url_response.folder_id + "/stats"

        Request-URL $egnyte_filestats_uri GET "N/A" $egnyte_headers "Egnyte Found Folder - Filecount GET"
        ## This is for Egnyte rate limiting due to Developer QPS
        Start-Sleep -Seconds 2

        $global:egnyte_filestats_response = $url_response.filescount

        if ($split_egnyte_folders) {
            $split_egnyte_projectfolders = @()
            $split_egnyte_projectfolders = $split_egnyte_folders -split "/Projects"
            $projectfolders = @()
            foreach ($split_folder in $split_egnyte_projectfolders) {
                if ($split_folder -match "[0-9]") {
                    $projectfolders += $split_folder
                }
            }
        }

        # This is where $projectfolders should be marked for the rest of the archiving process.
        # If Split Egnyte Folders was declared, meaning we have a duplicate, we will use "$projectfolders"
        # If there is no duplicate, that's fine, use the previous way of determining the name
        if ($split_egnyte_folders -And $project.project_active -eq $True) {
            foreach ($item in $projectfolders) {
                if ($item.Substring(1,7) -like "*$($project.client_code)*") {
                    Update-Slack "$($item.SubString(1)) is the selected folder. Project Drive folder selected."
                    $projectfolder = "$($item.SubString(1))"
                    Remove-Variable -name projectfolders
                    Remove-Variable -name split_egnyte_folders
                }
                if ($projectfolder) { continue }
            }
        } elseif ($split_egnyte_folders -And $project.project_active -eq $False) {
            [array]::Reverse($projectfolders)
            foreach ($item in $projectfolders) {
                if ($item.Substring(1,7) -like "*$($project.client_code)*") {
                    Update-Slack "$($item.SubString(1)) is the selected folder. Project Archive folder selected."
                    $projectfolder = "$($item.SubString(1))"
                    Remove-Variable -name projectfolders
                    Remove-Variable -name split_egnyte_folders
                }
                if ($projectfolder) { continue }
            }
        }
        
        # Implementing a "grab the folder's name and use it" check for $projectfolder
        if (!$projectfolder -And $project.egnyte_foundfolder) {
            $projectfolder = $project.egnyte_foundfolder -split '/Projects/'
            $projectfolder = $projectfolder[1]
            # If there's multiple folders in Projects Drive/Archive for this project, we can check that via '/', which can't be used in the egnyte_foundfolder name since anything after would be a new folder. 
            if($projectfolder -like "*/*") {
                $projectfolder = $projectfolder -split '/'
                $projectfolder = $projectfolder[0]
            }
            Update-Slack "$projectfolder is the selected folder name, pulled from egnyte_foundfolder"
        } elseif (!$projectfolder -or $null -eq $projectfolder) { # Implementing a null check / non-declared variable check for $projectfolder so it cannot be NULL or missing. (That way whole .../CLIENT/Projects/ folders won't be moved.)
            Update-Slack "$($project.project_folder) is the selected folder name, pulled from WMJ Project Folder Name."
            $projectfolder = $project.project_folder
        }

        # Adding removal of non-alphanumeric character to the end of $projectfolder so it's a valid path for Egnyte.
        if ($projectfolder -match '\W$') {
            $projectfolder = $projectfolder -split '\W$'
            $projectfolder = $projectfolder[0]
        } 
        if ($projectfolder -match '^/') {
            $projectfolder = $projectfolder -split '^/'
            $projectfolder = $projectfolder[1]
        }

        #########################
        # TRASH IF EMPTY        #
        #########################
        if ($global:egnyte_filestats_response -eq 0 -And $project.project_active -eq $False) {
            Update-Slack "Deleting  - $($project.egnyte_foundfolder)"
            Update-Slack "File Count = $global:egnyte_filestats_response"
            Request-URL $egnyte_folderstats_uri DELETE "N/A" $egnyte_headers "Egnyte Found Folder - Delete if empty"
        }

        #########################
        # WASABI MOVE           #
        #########################
        elseif (($project.project_number.SubString(0,2) -lt $prevyear) -And $project.egnyte_foundfolder -like "*Projects Archive*" -And $project.project_active -eq $False){
            Update-Slack "Moving $($project.project_number) to staging, older than 2 years and in Projects Archive."
            ## Define the API create folder action
            $project.egnyte_api_interaction = @{ action = 'add_folder' } | ConvertTo-JSON

            ## Create the Project Folder in the staging folder in Egnyte
            Update-Slack "Creating a folder in staging for $($project.project_number)"
            Request-URL "$egnyte_staging_toplevel_uri/$projectfolder" POST $project.egnyte_api_interaction $egnyte_headers "Egnyte Found Folder - Wasabi Move - Create folder in 'staging/_PROJECTS'"

            ## Create a variable to use as the destination for the API move request
            $egnyte_evac_dest="/Shared/staging/_PROJECTS/" + $project.client_name + "/Projects"

            ## Define the API move folder action & set the destination to the folder we just created in staging
            $project.egnyte_api_interaction = @{
                action='move'
                destination="$egnyte_evac_dest/$projectfolder"
            } | ConvertTo-JSON
            if ($project.egnyte_api_interaction -like '*“*' -or $project.egnyte_api_interaction -like '*”*') {
                $project.egnyte_api_interaction = $project.egnyte_api_interaction.replace('“','\u201C').replace('”','\u201D')
            }
            ## This is for Egnyte rate limiting due to Developer QPS
            Start-Sleep -Seconds 2
            
            ## Move the project folder to staging
            Update-Slack "Moving the project folder to staging..."
            Request-URL "$egnyte_archive_toplevel_uri/$projectfolder" POST $project.egnyte_api_interaction $egnyte_headers "Egnyte Found Folder - Wasabi Move - Move from 'Projects Archive' to 'staging'"
        }

        #########################
        # PROJECTS ARCHIVE MOVE #
        #########################
        elseif ($project.egnyte_foundfolder -like "*Projects Drive*" -And $project.project_active -eq $False) {
            ## Create a variable to use as the destination for the API move request
            $egnyte_archive_dest="/Shared/Projects Archive/" + $project.client_name + "/Projects"

            Update-Slack "Moving $($project.project_number) to Projects Archive, Project is Inactive and is within Projects Drive."
            ## Define the API create folder action
            $project.egnyte_api_interaction = @{ action = 'add_folder' } | ConvertTo-JSON

            ## Create the Project Folder in the Projects Archive folder in Egnyte
            Update-Slack "Creating a folder in Projects Archive for $($project.project_number)"
            Request-URL "$egnyte_archive_toplevel_uri/$projectfolder" POST $project.egnyte_api_interaction $egnyte_headers "Egnyte Found Folder - Archive Move - Create folder"

            ## Define the API move folder action & set the destination to the folder we just created in Projects Archive
            $project.egnyte_api_interaction = @{
                action='move'
                destination="$egnyte_archive_dest/$projectfolder"
            } | ConvertTo-JSON
            if ($project.egnyte_api_interaction -like '*“*' -or $project.egnyte_api_interaction -like '*”*') {
                $project.egnyte_api_interaction = $project.egnyte_api_interaction.replace('“',$open_quote).replace('”',$closed_quote)
            }
            ## This is for Egnyte rate limiting due to Developer QPS
            Start-Sleep -Seconds 2

            ## Move the project folder to the Projects Archive
            Update-Slack "Moving the project folder to Projects Archive."
            Request-URL "$egnyte_projects_toplevel_uri/$projectfolder" POST $project.egnyte_api_interaction $egnyte_headers "Egnyte Found Folder - Archive Move - Move from 'Projects Drive' to 'Projects Archive'"

            ## Now lets set user permissions as per the WMJ report
            #create variable for clean usernames
            $wmj_projectteam_clean = @()

            #foreach to get clean usernames up to there ^^^^
            Update-Slack "Starting User Permissions"
            foreach ($teammember in $project.project_team_original) 
            {
                $first = $teammember.SubString(0,1).ToLower()
                $last = $teammember.Split(" ") | Select-Object -Last 1 | ForEach-Object { $_.ToLower().Trim() } | ForEach-Object { $_.Replace('-', '') } 
                $username = $first + $last
                
                #this is where we dont include admins
                if ($egnyte_exclusions | Where-Object { $_ -like "$username"}) {
                    continue
                } else {} 


                #this is where we're going to check to see if the user exists in egnyte
                if ($egnyte_userlist.resources.username | Where-Object { $_ -like "$username"}) {
                    $wmj_projectteam_clean += $username
                } 
            }

            Update-Slack "User Permissions Completed"
            Update-Slack "Verifying proper inheritance settings of an archive folder"
        
            ## Set the URI for the Projects folder
            $egnyte_archive_inheritance_topleveluri = "REDACTED" + $project.client_name + "/Projects"
        
            ## Make sure that the Projects folder for that client exists in the Projects Archive
            Request-URL "$egnyte_archive_inheritance_topleveluri" GET "N/A" $egnyte_headers "Egnyte Found Folder - Archive Move - Archive Inheritance GET"
            ## This is for Egnyte rate limiting due to Developer QPS
            Start-Sleep -Seconds 2

            ## This will correct inheritance on the folder if inheritsPermissions is True -- because we do not want project folders to have Inheritance enabled
            if (($url_response.inheritsPermissions -like "*True*") -and ($project.egnyte_foundfolder -notlike "*PACPA*")) {
                Update-Slack "INCORRECT PERMISSIONS, CHANGING INHERITANCE"

                # POST Body Was: '{"inheritsPermissions":false,"keepParentPermissions":false}'
                $project.egnyte_api_interaction = @{
                    inheritsPermissions='false'
                    keepParentPermissions='false'
                } | ConvertTo-JSON
                ## Make the API request to disabled inheritance
                Request-URL "$egnyte_archive_inheritance_topleveluri" POST $project.egnyte_api_interaction $egnyte_headers "Egnyte Found Folder - Archive Move - Disable Top-Level Inheritance"

                ## This is for Egnyte rate limiting due to Developer QPS
                Start-Sleep -Seconds 2
                Update-Slack "CHANGED INHERITANCE"
            } else {
                Update-Slack "CORRECT INHERITANCE, PROCEEDING"
            }

            # Creating current project uri
            $egnyte_curproject_archive_uri="REDACTED" + "$egnyte_archive_dest/$projectfolder"
            ## API request to set inheritance
            # POST Body Was: '{"inheritsPermissions":false,"keepParentPermissions":false}'
            $project.egnyte_api_interaction = @{
                inheritsPermissions='false'
                keepParentPermissions='false'
            } | ConvertTo-JSON
            Request-URL "$egnyte_curproject_archive_uri" POST $project.egnyte_api_interaction $egnyte_headers "Egnyte Found Folder - Archive Move - Disable Current Project Inheritance"

            ## This is for Egnyte rate limiting due to Developer QPS
            Start-Sleep -Seconds 2

            ## foreach loop to build array of users who should have viewer access in the projects fodler in the Projects Archive in Egnyte
            foreach ($teammember in $wmj_projectteam_clean) {
                $project.egnyte_permissions_array += [ordered]@{$teammember = "Viewer";}
            }
            
            ## Build the request body for the Egnyte permissions API request
            $egnyte_permission_requestdata = New-Object PSObject
            $egnyte_permission_requestdata | Add-Member -MemberType NoteProperty -Name 'userPerms' -Value $project.egnyte_permissions_array
            $egnyte_permission_requestdata = $egnyte_permission_requestdata | ConvertTo-JSON -Depth 99

            ## API request to apply permissions with the new array of users who should be viewers
            Request-URL $egnyte_curproject_archive_uri POST $egnyte_permission_requestdata $egnyte_headers "Egnyte Found Folder - Archive Move - User permissions adjustment"
        }
    } elseif (!$project.egnyte_foundfolder) {
        Update-Slack "No folder found for project, proceeding on..."
        $project.egnyte_foundfolder = "No Folder Found OR Duplicate Folders in Drive + Archive"
    }
    ## Logging with Report of our object
    # Set our Egnyte Report's Date to be match the time/date of the flag file, aka the report is labelled for when the sync was run at
    $log_date = (Get-Date -Date (Get-ChildItem "REDACTED").LastWriteTime -Format MMddyy_HHmmsstt)
    $log_file = "REDACTED" + $log_date + "_archive_report.csv"
    Export-CSV -InputObject $project -Path $log_file -Append
    # Remove the current $project so we can move on with a clean slate for the next project in the list! 
    Remove-Variable $project

    ## This is for Egnyte rate limiting due to Developer QPS            
    Start-Sleep -Seconds 2
} 
# If there's nothing for us to work on, exit, just push a message that we didn't work on anything.
if (!$wmj_response) {
    Update-Slack "No projects to work on. Exiting..."
} elseif ($wmj_response) {
    Update-Slack "Done! Exiting..."
}

# Removing these Global variables for the next run, even though each Task scheduler PWSH task instance is new and purges these anyways
Remove-Variable -Scope Global -Name response
Remove-Variable -Scope Global -Name url_response
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime 
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Stopping Egnyte Projects archiving, Timestamp: $cDateTime"