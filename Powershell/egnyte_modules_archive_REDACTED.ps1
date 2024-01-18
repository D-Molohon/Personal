#################################################################
#
#                                                       
# Filename: egnyte_modules_archive.ps1                              
# Use: Moving Modules from Projects Drive to Wasabi  
# Author: DM       
# Requires: 
# Powershell 5.1 Compliance
# Egnyte API Guide:
# https://developers.egnyte.com/docs
#                                                                                                                         
#                 
# - 10/09/2023 - DM - Initial Script creation
#################################################################
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
                $global:url_response_error = 1
                Write-Output "Issue detected when attempting API POST or DELETE interaction at $label"
                Write-Output "HERE'S WHAT WAS ATTEMPTED: $U $M $B $H $label $($_.Exception)"
            }
        } else {
            try {
                $global:response=Invoke-WebRequest -URI $U -Method $M -Body $B -ContentType 'application/json; charset=UTF-8'
                $global:url_response = $global:response.Content | ConvertFrom-JSON
            } catch {
                $global:url_response_error = 1
                Write-Output "Issue detected when attempting API POST or DELETE interaction at $label"
                Write-Output "HERE'S WHAT WAS ATTEMPTED: $U $M $B $label $($_.Exception)"
            }
        }
    } elseif ("$M" -like "*GET*") {
        if ($B -like "*n/a*") {Remove-Variable B}
        try {
            $global:response=Invoke-WebRequest -URI $U -Method $M -Headers $H -ContentType 'application/json; charset=UTF-8'
            try {$global:url_response = $global:response.Content | ConvertFrom-JSON} catch {Write-Host "Non-JSON Body from GET request."}
        } catch {
            $global:url_response_error = 1
            Write-Output "Issue detected when attempting API GET interaction at $label"
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
Start-Sleep 1
$e_egnyte_accesstoken=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.Substring(2).replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
# Use the encrypted String in a PSCredential Object...
$egnyte_accesstoken_credential = New-Object System.Management.Automation.PsCredential("placeholder5", $e_egnyte_accesstoken)
# Grab the password part of the object we just made, which was decrypted and is stored in the PsCredential Object
$egnyte_accesstoken = $egnyte_accesstoken_credential.GetNetworkCredential().password

#########################
# EGNYTE VARIABLES      #
#########################
$egnyte_headers = @{ Authorization = "Bearer $egnyte_accesstoken" }

########################
# DECLARE SYNC START   #
########################
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Starting _ALL MODULES archiving, Timestamp: $cDateTime"

## Flag update
$flagDt=(Get-ChildItem "REDACTED").LastWriteTime
Remove-Item "REDACTED"
New-Item "REDACTED"
Update-Slack "Modules Archiving last ran at: $flagDt"

$createfolder = @{ action = 'add_folder' } | ConvertTo-JSON
Request-URL "REDACTED" POST $createfolder $egnyte_headers "Egnyte Create _MODULES Folder"

#set uri for rest method 
$egnyte_projects_toplevel_uri = "REDACTED"
#set uri for rest method - archive
# $egnyte_archive_toplevel_uri = "REDACTED"
#set uri for rest method - staging
$egnyte_staging_toplevel_uri = "REDACTED"

# Grabbing and making the tables for our client name and folder ID for Projects Drive and Projects Archive
# Projects Drive
Request-URL $egnyte_projects_toplevel_uri GET "N/A" $egnyte_headers "Project Folders Response"
$projects_folders = $url_response.folders | Sort-Object -Property "name"
foreach ($projectfolder in $projects_folders) {
    $projects_folderarray += [ordered]@{ $projectfolder.name = $projectfolder.folder_id}
}
# # Projects Archive
# Request-URL $egnyte_archive_toplevel_uri GET "N/A" $egnyte_headers "Project Archive Response"
# $archive_folders = $url_response.folders | Sort-Object -Property "name"
# foreach ($projectfolder in $archive_folders) {
#     $archive_folderarray += [ordered]@{ $projectfolder.name = $projectfolder.folder_id}
# }
# Folder structure is "REDACTED" + $projects_folderarray.key + "/_ALL MODULES"
$iterator = 0
foreach ($folder in $projects_folderarray.GetEnumerator()) {
    # Do something WACKY, absolutely BONKERS, send it to THE PIT
    $iterator = $iterator + 1
    $global:url_response_error = 0
    $current_projectfolder_uri = "REDACTED" + $folder.Key + "/_ALL MODULES"
    Clear-Variable url_response
    Request-URL $current_projectfolder_uri GET "N/A" $egnyte_headers "Modules Check"
    Start-Sleep -Seconds 1
    if ($global:url_response_error -eq 0) {
        $modules_array += [ordered]@{ $folder.Key = $folder.Value }
        Update-Slack "$iterator/$($projects_folderarray.count), $($folder.key) has a Modules folder!"
    } else {Update-Slack "$iterator/$($projects_folderarray.count), NO Modules folder for $($folder.key)."}
}
# Copy the _ALL MODULES folder contents to the _MODULES folder at /Shared/staging/_MODULES

$iterator = 0
foreach ($module in $modules_array.GetEnumerator()) {
    # Folder structure should be: /Shared/staging/_MODULES/$modules_array.Key/_ALL MODULES 
    $iterator = $iterator + 1
    # Import Create/Move folder logic from Archive script
    Update-Slack "$iterator/$($modules_array.count), Working on $($module.key)..."
    ## Define the API create folder action
    $egnyte_api_interaction = @{ action = 'add_folder' } | ConvertTo-JSON

    ## Create the Project Folder in the staging folder in Egnyte
    Update-Slack "Creating a folder in staging for: $($module.key)"
    Request-URL "$egnyte_staging_toplevel_uri/$($module.key)" POST $egnyte_api_interaction $egnyte_headers "Modules Copy - Create folder in 'staging/_PROJECTS'"

    ## Create a variable to use as the destination for the API move request
    $egnyte_evac_dest="/Shared/staging/_MODULES/" + $module.key + "/_ALL MODULES"

    ## Define the API move folder action & set the destination to the folder we just created in staging
    $egnyte_api_interaction = @{
        action='copy'
        destination="$egnyte_evac_dest"
    } | ConvertTo-JSON
    if ($egnyte_api_interaction -like '*“*' -or $egnyte_api_interaction -like '*”*') {
        $egnyte_api_interaction = $egnyte_api_interaction.replace('“','\u201C').replace('”','\u201D')
    }
    ## This is for Egnyte rate limiting due to Developer QPS
    Start-Sleep -Seconds 2
    
    ## Move the project folder to staging
    Update-Slack "Copying the _ALL MODULES folder to staging..."
    Request-URL "$egnyte_projects_toplevel_uri$($module.key)/_ALL MODULES" POST $egnyte_api_interaction $egnyte_headers "Modules Copy - Copy from 'Projects Drive' to 'staging'"
}
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime 
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Stopping Egnyte Modules archiving, Timestamp: $cDateTime"