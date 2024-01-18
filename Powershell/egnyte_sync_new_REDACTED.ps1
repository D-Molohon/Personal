#################################################################
#
#                                                       
# Filename: egnyte_sync_new.ps1                              
# Use: Egnyte Move to Archive Script        
# Author: DM       
# Requires: 
# Powershell 5.1 Compliance
# WMJ API Guide:
# https://support.workamajig.com/hc/en-us/articles/360023007451-API-Overview
# Egnyte API Guide:
# https://developers.egnyte.com/docs
#                                                                                                                   
#                 
# Additional Credit goes to TJB for the original Egnyte Sync
#################################################################

# To use "[List[string]]$project_team_original = [List[string]]::new()" in the WMJ_Project class, this needs to be the first line of the script and enabled use of a string list
using namespace System.Collections.Generic
# For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 
# SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module -Name CredentialManager
#Setting project_error due to oddities with Request_URL
$global:project_error = 0
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
            if ($project) {
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
$e_egnyte_accesstoken2=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
# Use the encrypted String in a PSCredential Object...
$wmj_apikey_credential = New-Object System.Management.Automation.PsCredential("placeholder1", $e_wmj_apikey)
$wmj_usertoken_credential = New-Object System.Management.Automation.PsCredential("placeholder2", $e_wmj_usertoken)
$wmj_report_credential = New-Object System.Management.Automation.PsCredential("placeholder3", $e_wmj_reportapikey)
$wmj_2020report_credential = New-Object System.Management.Automation.PsCredential("placeholder4", $e_wmj_2020reportapikey)
$egnyte_accesstoken2_credential = New-Object System.Management.Automation.PsCredential("placeholder5", $e_egnyte_accesstoken2)
# Grab the password part of the object we just made, which was decrypted and is stored in the PsCredential Object
$wmj_apikey = $wmj_apikey_credential.GetNetworkCredential().password
$wmj_usertoken = $wmj_usertoken_credential.GetNetworkCredential().password
$wmj_reportapikey = $wmj_report_credential.GetNetworkCredential().password
$wmj_2020reportapikey = $wmj_2020report_credential.GetNetworkCredential().password
$egnyte_accesstoken = $egnyte_accesstoken2_credential.GetNetworkCredential().password

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
# LOGGING               #
#########################
$slack_uri = "REDACTED"
function Update-Slack ([string]$one) {
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
$api_createfolder = @{ action = 'add_folder' } | ConvertTo-JSON
$egnyte_contractors="REDACTED"
$egnyte_interns="REDACTED"
$egnyte_freelancers="REDACTED"

########################
# DECLARE SYNC START   #
########################
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Starting Egnyte sync, Timestamp: $cDateTime"
########################
# WMJ API ACTIONS      #
######################## 
# grab date for query
# get all custom report
Update-Slack "Pulling WMJ Data..."
$wmjStatusCode=Invoke-WebRequest -Uri $wmj_endpoint -Headers $wmj_headers -ErrorVariable wmjErrorCheck
$wmjStatusCode=$wmjStatusCode.StatusCode
if ($wmjStatusCode -eq 200) {
    Update-Slack "WMJ API Status code is $wmjStatusCode. Updating last run time..."
} elseif (!$wmjStatusCode -eq 200) {
    Write-Output $wmjStatusCode
    Update-Slack "Unable to get Status Code of 200. Exiting Script and retrying."
    exit 1
}

# CZ - 2022/08/30 - Getting write time from the last time the flag was updated (hopefully the last run)
# DM - 2023/05/04 - Moving Flagging to after WMJ test, if the API fails it will exit the script and retry from last flag date.
$flagDt=(Get-ChildItem "REDACTED").LastWriteTime
remove-item "REDACTED"
new-item "REDACTED"
if ($flagDt) { Update-Slack "Sync last ran at: $flagDt" }

$wmj_apiresponse=@(
[pscustomobject]@{code='401';desc='The user token or the API access token is most likely invalid'}
[pscustomobject]@{code='207';desc='Multistatus. Some items are successful while others contain errors.'}
[pscustomobject]@{code='400';desc='Bad request - you have a missing token or invalid token.'}
[pscustomobject]@{code='404';desc='Not Found. Usually returned on a GET, this means the data you were looking for was not found.'}
[pscustomobject]@{code='429';desc='Too many requests.'}
[pscustomobject]@{code='500';desc='Internal server error.'}
)

$wmj_apiresponse | where-object code -like $wmjStatusCode -ov result | out-null
$result=($result | format-table -HideTableHeaders | out-string).Trim()

if ($result -ne '') {
    Update-Slack "Egnyte sync has encountered a WMJ API error: $result"
    exit
}

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

#new-item REDACTED
Start-Sleep -Seconds 1
if ($null -ne $flagDt) {
    $wmj_response = $wmj_request | Where-Object {(Get-Date $_.date_Updated) -ge $flagDt} | Sort-Object -Property date_updated -Descending
} else {
    write-host "No egnyte_sync flag found. Using current date/time minus 20 minutes as the baseline."
    $wmj_response = $wmj_request | Where-Object {(Get-Date $_.date_Updated) -gt (Get-Date -Date $tCurrentTime.AddMinutes(-20))} | Sort-Object -Property date_updated -Descending
}

Update-Slack "Checking if there are any projects that need worked on..."
if (!$wmj_response) {
    Update-Slack "No projects to work on :("
    Get-CurrentDate
    $cDateTime = Get-Date -Date $tCurrentTime
    $cDateTime = $cDateTime -replace "\n",""
    Update-Slack "Stopping Egnyte sync, Timestamp: $cDateTime"
    exit
} else {
    Update-Slack "There are projects to work on!"
}

$wmj_total_projects = $wmj_request.length
if ($wmj_response.length) {
    $wmj_response_total_projects = $wmj_response.length
} elseif (!$wmj_response.length -And $wmj_response) {
    $wmj_response_total_projects = 1
} else {
    $wmj_response_total_projects = 0
}

Update-Slack "We have...
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
Update-Slack "EGNYTE EXCLUDED USERS: $egnyte_exclusions"

#######################
# FILECOUNT FUNCTION  #
#######################
function Get-EgnyteFilecount ([string]$folder) {
    $egnyte_folderstats_uri = $folder
    Request-URL $egnyte_folderstats_uri GET "N/A" $egnyte_headers "Egnyte Filecount - Folderstats GET"
    ## This is for Egnyte rate limiting due to Developer QPS
    Start-Sleep -Seconds 2
    $egnyte_filestats_uri = "REDACTED" + $url_response.folder_id + "/stats"
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
    [string]$project_type
    [string]$project_number
    [string]$project_name
    [boolean]$project_active 
    [string]$project_members
    [string]$project_folder
    [string]$project_updated
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
    [System.Collections.Specialized.OrderedDictionary]$egnyte_topfolder_permissions_array = [ordered]@{}
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
    $project.project_type = $wmj_project.Project_Type
    $project.project_number = $wmj_project.Project_Number
    $project.project_name = $wmj_project.Project_Name -replace '[\\/:*?\"<>"(){}|#]',''
    $project.project_active = if ($wmj_project.Project_Status -like "*Complete*") {$False} elseif ($wmj_project.Project_Status -like "*Canceled*") {$False} else {$True}
    $wmj_projectteam_original = $wmj_project.Project_Team -replace "\(\w*\s*\w*\)", "" -split "," | ForEach-Object {$_.Trim()} | Sort-Object -Unique
    foreach ($member in $wmj_projectteam_original) {$project.project_team_original.Add($member)}
    $project.project_members = $project.project_team_original -join ", "
    $project.project_folder = $project.client_code + " - " + $project.project_name
    while ($project.project_folder -match '\W$') {
        $projectfolder = $project.project_folder -split '\W$'
        $project.project_folder = $projectfolder[0]
    }
    $project.project_updated = Get-Date $wmj_project.date_Updated -Format "hh:mm tt"
    
    Update-Slack "$iteration/$wmj_response_total_projects, Working on: $($project.project_number), which was updated $($project.project_updated). Project is: $(if ($project.project_active) {"Active"} else {"Inactive"}). Project type is $($project.project_type)"

    #set uri for rest method 
    $egnyte_projects_toplevel_uri = "REDACTED" + $project.client_name + "/Projects"
    #naptime - egnyte rate limiting
    Start-Sleep -Seconds 1
    #set uri for rest method - archive
    $egnyte_archive_toplevel_uri = "REDACTED" + $project.client_name + "/Projects"
    #ask every folder what it has in it
    Request-URL $egnyte_projects_toplevel_uri GET "N/A" $egnyte_headers "Project Folders Response"
    $project.egnyte_projectfolders_response = $url_response
    Start-Sleep -Seconds 2

    #This will error if archive dir not present
    Request-URL $egnyte_archive_toplevel_uri GET "N/A" $egnyte_headers "Project Archive Response"
    if ($project_error -eq 1) {
        $project.egnyte_archivefolders_response = ""
        $global:project_error = 0
    } else {
        $project.egnyte_archivefolders_response = $url_response
    }

    #put these results in the array
    $project.egnyte_projectfolders = $project.egnyte_projectfolders_response.folders
    $project.egnyte_projectfolders += $project.egnyte_archivefolders_response.folders
    Start-Sleep -Seconds 2

    $project.egnyte_foundfolder = $project.egnyte_projectfolders.Path | Where-Object { $_ -like "*/Projects/$($project.client_code)*" }
    # Adding removal of non-alphanumeric character to the end of $egnyte_foundfolder so it's a valid path for Egnyte.
    if ($project.egnyte_foundfolder -match '\W$') {
        $projectfolder = $project.egnyte_foundfolder -split '\W$'
        $project.egnyte_foundfolder = $projectfolder[0]
    } 
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
                    $project.egnyte_foundfolder = $projectdrive_egnyte_foundfolder
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
                    $project.egnyte_foundfolder = $projectarchive_egnyte_foundfolder
                }
            }
        }
    }
    if (!$project.egnyte_foundfolder) {
        Update-Slack "DID NOT FIND FOLDER FOR - $($project.project_folder)"
        Update-Slack "Checking on $($project.project_number) to see if we are able to make a folder for it!"
        #this is the stupidest thing below. You have to convert it to the date first, because it will return a incorrect value otherwise...
        if ((Get-Date $wmj_project.project_Start_Date) -gt (Get-Date -Date $tCurrentTime).AddMonths(-9) -and $wmj_project.cF_PDrive -like "*Yes*") {
            Update-Slack "The project folder should be created! Let's help out."
            if (!$project.egnyte_projectfolders_response) {
                Update-Slack "Oooh, a new client! Cool! Let's make the top levels first..."
                #lets make our folder array
                $egnyte_topfolder_creation_array = ""
                $egnyte_topfolder_creation_array = @(
                    "REDACTED"
                )
                #make the webrequest
                foreach ($egnyte_topfolder_creation_uri in $egnyte_topfolder_creation_array) {
                Request-URL $egnyte_topfolder_creation_uri POST $api_createfolder $egnyte_headers "Egnyte No Found Folder - Create Top Level Folder"
                Start-Sleep -Milliseconds 200
                }
            }
            Update-Slack "We assume the client exists, because we found a client folder..."
            #lets make our folder array
            $egnyte_projectfolder_creation_array = ""
            if ($project.project_type -like "REDACTED") {
                $egnyte_projectfolder_creation_array = @(
                    "REDACTED"
                )
            } else {
                $egnyte_projectfolder_creation_array = @(
                    "REDACTED"
                )
            }
            #set the folder to found now so we can apply permissions in one swipe! amazing!
            $project.egnyte_foundfolder = "/Shared/Projects Drive/$($project.client_name)/Projects/$($project.project_folder)"
            if ($project.egnyte_foundfolder -match '\W$') {
                $projectfolder = $project.egnyte_foundfolder -split '\W$'
                $project.egnyte_foundfolder = $projectfolder[0]
            }
            #make the webrequest
            foreach ($egnyte_projectfolder_creation_uri in $egnyte_projectfolder_creation_array) {
                Request-URL $egnyte_projectfolder_creation_uri POST $api_createfolder $egnyte_headers "Egnyte No Found Folder - Create Project Folder"
                Start-Sleep -Milliseconds 200
                }   
            } elseif ((Get-Date $wmj_project.project_Start_Date) -le (Get-Date -Date $tCurrentTime).AddMonths(-6) -and $wmj_project.cF_PDrive -like "*Yes*") {
                Update-Slack "Project folder is required for this project, but the start date is over 9 months, moving on."
            } else {Update-Slack "Project folder is not required for this project per WMJ, moving on."}
        }
    if($project.egnyte_foundfolder) {
        Update-Slack "FOUND FOLDER! - $($project.egnyte_foundfolder) - Checking Permissions"
        #check if its archive or projects
        if ($project.egnyte_foundfolder -like "*Projects Drive*") {Update-Slack "This is a project folder!"}
        if ($project.egnyte_foundfolder -like "*Projects Archive*") {Update-Slack "This is an archive folder!"}
        ###################################################
        # USER LIST CREATION
        ###################################################
        #create variable for clean usernames
        $wmj_projectteam_clean = @()
        #foreach to get clean usernames up to there ^^^^
        Update-Slack "Starting User Permissions"
        foreach ($teammember in $project.project_team_original) 
        {
            $first = $teammember.SubString(0,1).ToLower()
            $last = $teammember.Split(" ") | Select-Object -Last 1 | ForEach-Object { $_.ToLower().Trim() } | ForEach-Object { $_.Replace('-', '') } 
            $username = $first + $last

            ## Fix the username for REDACTED REDACTED
            if ($username -like "REDACTED") {$username = "REDACTED"}
            
            #this is where we dont include admins
            if ($egnyte_exclusions | Where-Object { $_ -like "$username"}) {
                continue
            } else {} 
            #this is where we're going to check to see if the user exists in egnyte
            if ($egnyte_userlist.resources.username | Where-Object { $_ -like "$username"}) {
                $wmj_projectteam_clean += $username
            } 
        }
        Update-Slack "User Permissions Completed!"
        ############################
        # PROJECTS INHERITANCE VERIFICATION #
        ############################
        if ($project.egnyte_foundfolder -like "*Projects Drive*") {
        Update-Slack "Verifying proper inheritance settings of a project folder"
        $egnyte_project_inheritance_topleveluri = "REDACTED" + $project.client_name + "/Projects"
        Request-URL $egnyte_project_inheritance_topleveluri GET "N/A" $egnyte_headers "Egnyte Projects Inheritance Verification"
        $egnyte_project_inheritance_toplevelcheck = $url_response
        Start-Sleep -Seconds 1
        if (($egnyte_project_inheritance_toplevelcheck.inheritsPermissions -like "*True*") -and ($project.egnyte_foundfolder -notlike "REDACTED")) {
            Update-Slack "INCORRECT PERMISSIONS, CHANGING INHERITANCE"
            Request-URL $egnyte_project_inheritance_topleveluri POST '{"inheritsPermissions":false,"keepParentPermissions":false}' $egnyte_headers "Egnyte Project Inheritance Change"
            Start-Sleep -Seconds 1
            Update-Slack "CHANGED INHERITANCE"
        } else {Update-Slack "CORRECT INHERITANCE, PROCEEDING"}
        #assign top level folder permission URI
        $egnyte_topfolder_permission_uri = "REDACTED" + $project.client_name
        }
        ############################
        # ARCHIVE INHERITANCE VERIFICATION #
        ############################
        #if archive, check top level
        if ($project.egnyte_foundfolder -like "*Projects Archive*") {
            Update-Slack "Verifying proper inheritance settings of an archive folder"
            $egnyte_archive_inheritance_topleveluri = "REDACTED" + $project.client_name + "/Projects"
            Request-URL $egnyte_archive_inheritance_topleveluri GET "N/A" $egnyte_headers "Egnyte Archive Inheritance Verification"
            $egnyte_archive_inheritance_toplevelcheck = $url_response
            Start-Sleep -Seconds 1
            if (($egnyte_archive_inheritance_toplevelcheck.inheritsPermissions -like "*True*") -and ($project.egnyte_foundfolder -notlike "REDACTED")) {
                Update-Slack "INCORRECT PERMISSIONS, CHANGING INHERITANCE"
                Request-URL $egnyte_archive_inheritance_topleveluri POST '{"inheritsPermissions":false,"keepParentPermissions":false}' $egnyte_headers "Egnyte Archive Inheritance Change"
                Start-Sleep -Seconds 1
                Update-Slack "CHANGED INHERITANCE"
                Start-Sleep -Seconds 1
            } else {Update-Slack "CORRECT INHERITANCE, PROCEEDING"}
            #assign top level folder permission URI
            $egnyte_topfolder_permission_uri = "REDACTED" + $project.client_name
        }
        Start-Sleep -Seconds 3
        ###################################################
        #grab current permissions on project folder
        $egnyte_permissions_uri = "REDACTED" + $project.egnyte_foundfolder
        Request-URL $egnyte_permissions_uri GET "N/A" $egnyte_headers "Egnyte Check Current Project Permissions"
        $egnyte_permissions_response = $url_response
        Start-Sleep -Seconds 2
        #grab current topfolder permissions
        Request-URL $egnyte_topfolder_permission_uri GET "N/A" $egnyte_headers "Egnyte Check Current Project Top Folder Permissions"
        $egnyte_topfolder_permission_response = $url_response
        Start-Sleep -Seconds 2
        $egnyte_permissions_currentfolder = $egnyte_permissions_response.userPerms | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        $egnyte_permissions_topfolder = $egnyte_topfolder_permission_response.userPerms | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        # have to wrap this in try\catch because $null variables make it freakout, if it fails, fill the variable with $wmj_projectteam_clean
        # mark the empty user permission variable so it can be picked up in the loop (only with new folders)
        try {
            $egnyte_required_permissions = Compare-Object $egnyte_permissions_currentfolder $wmj_projectteam_clean
            $egnyte_empty_userpermissions = $false
        } catch {
            $egnyte_empty_userpermissions = $true
            $egnyte_required_permissions = $wmj_projectteam_clean
        }
        try {
            $egnyte_empty_topfolder_userpermissions = $false
            $egnyte_required_topfolder_permissions = Compare-Object $egnyte_permissions_topfolder $wmj_projectteam_clean
        } catch {
            $egnyte_empty_topfolder_userpermissions = $true
            $egnyte_required_topfolder_permissions = $wmj_projectteam_clean
        }
        #remove egnyte exclusions
        foreach ($user in $egnyte_exclusions) {
            if ($egnyte_required_permissions -contains $user) {
                $egnyte_list_index = ($egnyte_required_permissions.IndexOf("$user"))
                $egnyte_required_permissions.RemoveAt($egnyte_list_index)
            }
            if ($egnyte_required_topfolder_permissions -contains $user) {
                $egnyte_list_index = ($egnyte_required_topfolder_permissions.IndexOf("$user"))
                $egnyte_required_topfolder_permissions.RemoveAt($egnyte_list_index)
            }
        }
        ###################################
        ######## NOTIFY IF IN-SYNC ########
        # NOTE: If the WMJ permissions are empty, the $user username is used. (Due to lack of multiple items stored in $user)
        # NOTE: If the WMJ permissions are NOT empty, the $user.InputObject username is used. (Due to multiple items stored in $user)
        if (!$egnyte_required_permissions) { 
            Update-Slack "Permissions are in-sync." 
        } else {
        ####### FIX PERMISSIONS for PROJECT FOLDER #######
        foreach ($user in $egnyte_required_permissions) {
            # Check if user is not in exclusions
            if (!$egnyte_exclusions.Contains($user.InputObject)) {
                #if nothing to compare, load whole list
                if ($egnyte_empty_userpermissions -eq $true) {
                    #create array, and add 1 user at a time, cycling through
                    if ($project.egnyte_foundfolder -like "*Projects Drive*") {
                            $project.egnyte_permissions_array += [ordered]@{$user = "Full";}
                        }
                    if ($project.egnyte_foundfolder -like "*Projects Archive*") {
                            $project.egnyte_permissions_array += [ordered]@{$user = "Viewer";}
                        }
                    Update-Slack "Applying permissions for: $user to folder: $($project.egnyte_foundfolder)"
                }
                #if user shows as needing added, add user
                if ($user.sideindicator -eq "=>") {
                    if ($project.egnyte_foundfolder -like "*Projects Drive*") {
                            $project.egnyte_permissions_array += [ordered]@{$($user.InputObject) = "Full";}
                        }
                    if ($project.egnyte_foundfolder -like "*Projects Archive*") {
                            $project.egnyte_permissions_array += [ordered]@{$($user.InputObject) = "Viewer";}
                        }
                    Update-Slack "Applying permissions for: $($user.InputObject) to folder: $($project.egnyte_foundfolder)"
                }
                #if user shows as needing removed, remove user
                if ($user.sideindicator -eq "<=") {
                    # CHANGE THE LIKE STATEMENT IF WE RENAME THE USERNAMES
                    if ($user.InputObject -like "*fci*") {
                        Update-Slack "Found Contractor in permissions, continuing"
                        continue
                    } elseif ($egnyte_exclusions -contains $user.InputObject) {
                        Update-Slack "$($user.InputObject) is in Egnyte Exclusions, continuing on..."
                        continue
                    }
                    $project.egnyte_permissions_array += [ordered]@{$($user.InputObject) = "None";}
                    Update-Slack "Removing permissions for: $($user.InputObject) from folder: $($project.egnyte_foundfolder)"
                }
            }
        }
        ####### FIX TOP LEVEL PERMISSIONS #######
        foreach ($user in $egnyte_required_topfolder_permissions) {
            # Check if user is not in exclusions
            if (!$egnyte_exclusions.Contains($user.InputObject)) {
            #if nothing to compare, load whole list
                if ($egnyte_empty_topfolder_userpermissions -eq $true) {
                    if ($project.egnyte_foundfolder -like "*Projects Drive*") {
                            $project.egnyte_topfolder_permissions_array += [ordered]@{$user = "Full";}
                        }
                    if ($project.egnyte_foundfolder -like "*Projects Archive*") {
                            $project.egnyte_topfolder_permissions_array += [ordered]@{$user = "Viewer";}
                        }
                    Update-Slack "Applying top level permissions for: $user to folder: $($project.client_name)"
                }
                #if user shows as needing added, add user
                if ($user.sideindicator -eq "=>") {
                        #create array, and add 1 user at a time, cycling through
                    if ($project.egnyte_foundfolder -like "*Projects Drive*") {
                            $project.egnyte_topfolder_permissions_array += [ordered]@{$($user.InputObject) = "Full";}
                        }
                    if ($project.egnyte_foundfolder -like "*Projects Archive*") {
                            $project.egnyte_topfolder_permissions_array += [ordered]@{$($user.InputObject) = "Viewer";}
                        }
                    Update-Slack "Applying top level permissions for: $($user.InputObject) to folder: $($project.client_name)"
                }
            }
        }
        $egnyte_permission_requestdata = New-Object PSObject
                    $egnyte_permission_requestdata | Add-Member -MemberType NoteProperty -Name 'userPerms' -Value $project.egnyte_permissions_array
                    $egnyte_permission_requestdata = $egnyte_permission_requestdata | ConvertTo-JSON -Depth 99
        Request-URL $egnyte_permissions_uri POST $egnyte_permission_requestdata $egnyte_headers "Egnyte Project Folder Permissions"
        Start-Sleep -Seconds 1
        Update-Slack "Project Folder Permission Applied"
        $egnyte_topfolder_permission_requestdata = New-Object PSObject
                    $egnyte_topfolder_permission_requestdata | Add-Member -MemberType NoteProperty -Name 'userPerms' -Value $project.egnyte_topfolder_permissions_array
                    $egnyte_topfolder_permission_requestdata =  $egnyte_topfolder_permission_requestdata | ConvertTo-JSON -Depth 99
        Request-URL $egnyte_topfolder_permission_uri POST $egnyte_topfolder_permission_requestdata $egnyte_headers "Egnyte Project Top Folder Permissions"
        Start-Sleep -Seconds 1
        Update-Slack "Top Level Folder Permissions Applied"
        }
    }
    ## Logging with Report of our object
    # Set our Egnyte Report's Date to be match the time/date of the flag file, aka the report is labeled for when the sync was run at
    $log_date = (Get-Date -Date (Get-ChildItem "REDACTED").LastWriteTime -Format MMddyy_HHmmsstt)
    $log_file = "REDACTED" + $log_date + "_sync_report.csv"
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
Update-Slack "Stopping Egnyte sync, Timestamp: $cDateTime"