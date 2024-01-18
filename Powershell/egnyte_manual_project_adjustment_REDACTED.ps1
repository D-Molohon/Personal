#################################################################
#
#                                                       
# Filename: egnyte_manual_project_adjustment.ps1                              
# Use: Manually eval a project's permissions in WMJ, adjust Egnyte Folder accordingly        
# Authors: DMolohon         
# Requires: 
# Powershell 5.1 Compliance
# WMJ API Guide:
# https://support.workamajig.com/hc/en-us/articles/360023007451-API-Overview
# Egnyte API Guide:
# https://developers.egnyte.com/docs
#        
# Made with parts from egnyte-sync.ps1 and egnyte_archive.ps1, so credit also goes to TBernath and CZimmerman                                                                                        
#################################################################
# SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 
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

########################
# USER INPUT           #
########################
$u_checkwhich = (Read-Host "What are we checking? Please type either 'client' OR 'project', without quotes.") 

if ($u_checkwhich -like "*project*") {
    ## BY PROJECT CODE
    Write-Host 'Please enter the project as the following: ##-CLIENT-####'
    $u_project = (Read-Host "What project are we re-checking?")
} elseif ($u_checkwhich -like "*client*") {
    ## BY CLIENT NAME
    Write-Host 'Please enter the client name as all caps, for example: ABC00'
    $u_project = (Read-Host "What client are we re-checking?")
} else {
    Write-Host "Unsure of what user is requesting to check, exiting."
    exit 1
}

########################
# WMJ API ACTIONS      #
########################
$wmjStatusCode=Invoke-WebRequest -Uri $wmj_endpoint -Headers $wmj_headers -ErrorVariable wmjErrorCheck
$wmjStatusCode=$wmjStatusCode.StatusCode
if ($wmjStatusCode -eq 200) {
    Write-Host "WMJ API Status code is $wmjStatusCode."
} elseif (!$wmjStatusCode -eq 200) {
    Write-Host "Unable to get Status Code of 200 from WMJ. Exiting Script and retrying."
    exit 1
}

Write-Host "Pulling the WMJ report..."
$wmj_request = @() 
Start-Sleep -Seconds 1
$wmj_request += Invoke-RestMethod -Uri $wmj_endpoint -Headers $wmj_headers -Method GET -ContentType "application/json"
Start-Sleep -Seconds 1
$wmj_request += Invoke-RestMethod -Uri $wmj_2020endpoint -Headers $wmj_headers -Method GET -ContentType "application/json"

$wmj_response = $wmj_request.data.report | Sort-Object -Property date_updated -Descending
Write-Host "WMJ Report pulled"

$wmj_filtered_response = @()
if ($u_checkwhich -like "*project*") {
    ## BY PROJECT CODE
    if ($wmj_response.project_Number -contains $u_project) {
        $wmj_filtered_response = $wmj_response | Where project_Number -like $u_project
    } else {
        Write-Host "Unable to find project requested, exiting."
        exit 1
    }
} elseif ($u_checkwhich -like "*client*") {
    ## BY CLIENT NAME
    if ($wmj_response | Where project_Number -like "*$u_project*") {
        $wmj_filtered_response += $wmj_response | Where project_Number -like "*$u_project*"
    } else {
        Write-Host "Unable to find client requested, exiting."
        exit 1  
    }
} else {
    Write-Host "Unsure of what user is requesting to check, exiting."
    exit 1
}

########################
# EGNYTE API ACTIONS   #
########################
$egnyteStatusCheck=Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $egnyte_headers

if ($egnyteStatusCheck.StatusCode -ne 200) {
    Write-Host "EGNYTE API CHECK FAILED, STATUS CODE: $($egnyteStatusCheck.StatusCode)"
    Get-CurrentDate
    $cDateTime = Get-Date -Date $tCurrentTime
    $cDateTime = $cDateTime -replace "\n",""
    Write-Host "Stopping archiving, Timestamp: $cDateTime"
    exit
} elseif ($egnyteStatusCheck.StatusCode -eq 200) {
    Write-Host "Egnyte API Check Completed, Status Code: $($egnyteStatusCheck.StatusCode), proceeding... "
}

## Getting Egnyte User Information
#get a list of users from egnyte to reference
$egnyte_userlist = @()
$egnyte_userlist += Invoke-RestMethod -URI "REDACTED"  -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1
$egnyte_userlist += Invoke-RestMethod -URI "REDACTED"  -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1
$egnyte_userlist += Invoke-RestMethod -URI "REDACTED"  -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1
$egnyte_userlist += Invoke-RestMethod -URI "REDACTED"  -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1

$egnyte_groupeduserlist = @()
$egnyte_groupeduserlist += Invoke-RestMethod -URI "$egnyte_contractors" -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1
$egnyte_groupeduserlist += Invoke-RestMethod -URI "$egnyte_interns" -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1
$egnyte_groupeduserlist += Invoke-RestMethod -URI "$egnyte_freelancers" -Method GET -Headers $egnyte_headers -ContentType "application/json" 
Start-Sleep -Seconds 1
$egnyte_exclusions = @()
#Admin Exclusion
$egnyte_exclusions += $egnyte_userlist.resources | Where-Object { $_.usertype -like "admin" } | ForEach-Object { $_.username }
#Freelancer, Contractor, and Intern Exclusions
$egnyte_exclusions += $egnyte_groupeduserlist.members.username

foreach ($wmj_project in $wmj_filtered_response) {
    $wmj_clientname = $wmj_project.Project_Number | Select-String -Pattern '-\w+-' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | ForEach-Object {$_.Trim() -replace '-',''}
    $wmj_clientcode = $wmj_project.Project_Number | ForEach-Object { $_.Replace($wmj_clientname,'') } | Out-String | ForEach-Object {$_.Trim() -replace '-',''} | ForEach-Object {$_.Trim() -replace '[\s]',''}
    $wmj_projecttype = $wmj_project.Project_Type
    $wmj_projectnumber = $wmj_project.Project_Number
    $wmj_projectname = $wmj_project.Project_Name -replace '[\\/:*?\"<>"(){}|]','' | ForEach-Object {$_.Trim()}
    $wmj_projectstatus = if ($wmj_project.Project_Status -like "*Project is Complete*") {"inactive"} elseif ($wmj_project.Project_Status -like "*Canceled*") {"inactive"} else {"active"}
    $wmj_projectteam_original = $wmj_project.Project_Team -replace "\(\w*\s*\w*\)", "" -split "," | ForEach-Object {$_.Trim()} | Sort-Object -Unique
    $wmj_projectfolder = $wmj_clientcode + " - " + $wmj_projectname
    $wmj_projectdateupdated = Get-Date $wmj_project.date_Updated -Format "hh:mm tt"
    $wmj_campaignID = $wmj_project.campaign_ID
    #$wmj_campaignID_formatted = $wmj_campaignID | ForEach-Object { $_.Replace($wmj_clientname,'') } | Out-String | ForEach-Object {$_.Trim() -replace '-',''} | ForEach-Object {$_.Trim() -replace '[\s]',''}
    #$wmj_campaignname = $wmj_project.campaign_Name -replace '[\\/:*?\"<>"(){}|]','' | ForEach-Object {$_.Trim()}
    #$wmj_campaignfolder = $wmj_campaignID + " - " + $wmj_campaignname
    Write-Host "Working on: $wmj_projectnumber which was updated $wmj_projectdateupdated Project status is $wmj_projectstatus Project type is $wmj_projecttype"
    if ($wmj_campaignID -ne '') {
        Write-Host "Project has a campaign code of: $wmj_campaignID"
    } elseif ($wmj_campaignID -eq '') {
        Write-Host "Project has no campaign code. Continuing on!"
    }
    #########
    #clear variable (fix for double add's on line 65)
    $egnyte_projectfolders_response = ""
    $egnyte_archivefolders_response = ""
    #clear variable
    $egnyte_projectfolders = @()
    #set uri for rest method
    $egnyte_projects_toplevel_uri = "REDACTED" + $wmj_clientname + "/Projects"
    Start-Sleep -Seconds 1
    $egnyte_archive_toplevel_uri = "REDACTED" + $wmj_clientname + "/Projects"
    #ask every folder what it has in it
    $egnyte_projectfolders_response = Invoke-RestMethod -URI $egnyte_projects_toplevel_uri -Method GET -Headers $egnyte_headers -ContentType "application/json"
    Start-Sleep -Seconds 1
    $egnyte_archivefolders_response = Invoke-RestMethod -URI $egnyte_archive_toplevel_uri -Method GET -Headers $egnyte_headers -ContentType "application/json"
    #put these results in the array
    $egnyte_projectfolders = $egnyte_projectfolders_response.folders
    $egnyte_projectfolders += $egnyte_archivefolders_response.folders
    #########
    # logic to find client code in folder path
    $egnyte_foundfolder = $egnyte_projectfolders.Path | Where-Object { $_ -like "*$wmj_clientcode*" }  
    if($egnyte_foundfolder) {
        if ($wmj_projectstatus -eq "active" -And $egnyte_foundfolder -like "*Projects Drive*" -And $egnyte_foundfolder -like "*Projects Archive*") {
            $egnyte_foundfolder = $egnyte_foundfolder | Select-Object -First 1
        } elseif ($wmj_projectstatus -eq "inactive" -And $egnyte_foundfolder -like "*Projects Drive*" -And $egnyte_foundfolder -like "*Projects Archive*") {
            $egnyte_foundfolder = $egnyte_foundfolder | Select-Object -Skip 1 | Select-Object -First 1
        }
        Write-Host "FOUND FOLDER! - $egnyte_foundfolder - Checking Permissions"
        #TODO: CHECK IF NEEDS RENAMED
        #check if its archive or projects
        if ($egnyte_foundfolder -like "*Projects Drive*") {Write-Host "This is a project folder!"}
        if ($egnyte_foundfolder -like "*Projects Archive*") {Write-Host "This is an archive folder!"}
        ###################################################
        # USER LIST CREATION
        ###################################################
        #create variable for clean usernames
        $wmj_projectteam_clean = @()
        #foreach to get clean usernames up to there ^^^^
        Write-Host "Starting User Permissions"
        foreach ($teammember in $wmj_projectteam_original) 
        {
            $first = $teammember.SubString(0,1).ToLower()
            $last = $teammember.Split(" ") | Select-Object -Last 1 | ForEach-Object { $_.ToLower().Trim() } | ForEach-Object { $_.Replace('-', '') } 
            $username = $first + $last

            ## Fix the username for Beth Buchanan
            if ($username -like "bBuchanan") {
                $username = "eBuchanan"
            }

            #this is where we dont include admins
            if ($egnyte_exclusions | Where-Object { $_ -like "$username"}) {
                continue
            } else {} 
            #this is where we're going to check to see if the user exists in egnyte
            if ($egnyte_userlist.resources.username | Where-Object { $_ -like "$username"}) {
                $wmj_projectteam_clean += $username
            } 
        }
        Write-Host "User Permissions Completed!"
        ############################
        # PROJECTS INHERITANCE VERIFICATION #
        ############################
        if ($egnyte_foundfolder -like "*Projects Drive*") {
        Write-Host "Verifying proper inheritance settings of a project folder"
        $egnyte_project_inheritance_topleveluri = "REDACTED" + $wmj_clientname + "/Projects"
        $egnyte_project_inheritance_toplevelcheck = Invoke-RestMethod -URI $egnyte_project_inheritance_topleveluri -Method GET -Headers $egnyte_headers -ContentType "application/json"
        Start-Sleep -Seconds 1
        if (($egnyte_project_inheritance_toplevelcheck.inheritsPermissions -like "*True*") -and ($egnyte_foundfolder -notlike "*PACPA*")) {
            Write-Host "INCORRECT PERMISSIONS, CHANGING INHERITANCE"
            Invoke-RestMethod -URI $egnyte_project_inheritance_topleveluri -Method POST -Headers $egnyte_headers -ContentType "application/json" -Body '{"inheritsPermissions":false,"keepParentPermissions":false}'
            Start-Sleep -Seconds 1
            Write-Host "CHANGED INHERITANCE"
        } else {Write-Host "CORRECT INHERITANCE, PROCEEDING"}
        #
        #assign top level folder permission URI
        $egnyte_topfolder_permission_uri = "REDACTED" + $wmj_clientname
        #
        }
        ############################
        # ARCHIVE INHERITANCE VERIFICATION #
        ############################
        #if archive, check top level
        if ($egnyte_foundfolder -like "*Projects Archive*") {
            Write-Host "Verifying proper inheritance settings of an archive folder"
            $egnyte_archive_inheritance_topleveluri = "REDACTED" + $wmj_clientname + "/Projects"
            $egnyte_archive_inheritance_toplevelcheck = Invoke-RestMethod -URI $egnyte_archive_inheritance_topleveluri -Method GET -Headers $egnyte_headers -ContentType "application/json"
            Start-Sleep -Seconds 3
            if (($egnyte_archive_inheritance_toplevelcheck.inheritsPermissions -like "*True*") -and ($egnyte_foundfolder -notlike "*PACPA*")) {
                Write-Host "INCORRECT PERMISSIONS, CHANGING INHERITANCE"
                Invoke-RestMethod -URI $egnyte_archive_inheritance_topleveluri -Method POST -Headers $egnyte_headers -ContentType "application/json" -Body '{"inheritsPermissions":false,"keepParentPermissions":false}'
                Start-Sleep -Seconds 1
                Write-Host "CHANGED INHERITANCE"
                Start-Sleep -Seconds 3
            } else {Write-Host "CORRECT INHERITANCE, PROCEEDING"}
            #
            #assign top level folder permission URI
            $egnyte_topfolder_permission_uri = "REDACTED" + $wmj_clientname
            #
        }
        #########
        Start-Sleep -Seconds 5
        ###################################################
        #grab current permissions on project folder
        $egnyte_permissions_uri = "REDACTED" + $egnyte_foundfolder
        $egnyte_permissions_response = Invoke-RestMethod -URI $egnyte_permissions_uri -Method GET -Headers $egnyte_headers -ContentType "application/json" 
        Start-Sleep -Seconds 3
        #
        #grab current topfolder permissions
        $egnyte_topfolder_permission_response = Invoke-RestMethod -URI $egnyte_topfolder_permission_uri -Method GET -Headers $egnyte_headers -ContentType "application/json" 
        Start-Sleep -Seconds 3
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
            $egnyte_empty__topfolder_userpermissions = $false
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
        ############################################
        ######### NOTIFY IF IN-SYNC ################
        if (!$egnyte_required_permissions) { 
            Write-Host "Permissions are in-sync." 
        } else {
        $egnyte_permissions_array = [ordered]@{}
        $egnyte_topfolder_permissions_array = [ordered]@{}
        ##### FIX PERMISSIONS for PROJECT FOLDER
        foreach ($user in $egnyte_required_permissions) {
            # Check if user is not in exclusions
            if (!$egnyte_exclusions.Contains($user.InputObject)) {
                #if nothing to compare, load whole list
                if ($egnyte_empty_userpermissions -eq $true) {
                    if ($user.InputObject -eq $null) {Write-Host "No InputObject detected."}
                    #create array, and add 1 user at a time, cycling through
                    if ($egnyte_foundfolder -like "*Projects Drive*") {
                            $egnyte_permissions_array += [ordered]@{$user = "Full";}
                        }
                    if ($egnyte_foundfolder -like "*Projects Archive*") {
                            $egnyte_permissions_array += [ordered]@{$user = "Viewer";}
                        }
                    Write-Host "Applying permissions for: $user to folder: $egnyte_foundfolder"
                }
                #if user shows as needing added, add user
                if ($user.sideindicator -eq "=>") {
                    if ($egnyte_foundfolder -like "*Projects Drive*") {
                            $egnyte_permissions_array += [ordered]@{$($user.InputObject) = "Full";}
                        }
                    if ($egnyte_foundfolder -like "*Projects Archive*") {
                            $egnyte_permissions_array += [ordered]@{$($user.InputObject) = "Viewer";}
                        }
                    Write-Host "Applying permissions for: $($user.InputObject) to folder: $egnyte_foundfolder"
                }
                #if user shows as needing removed, remove user
                if ($user.sideindicator -eq "<=") {
                    # CHANGE THE LIKE STATEMENT IF WE RENAME THE USERNAMES
                    if ($user.InputObject -like "*fci*") {
                        Write-Host "Found Contractor in permissions, continuing"
                        continue
                    }
                    $egnyte_permissions_array += [ordered]@{$($user.InputObject) = "None";}
                    Write-Host "Removing permissions for: $($user.InputObject) from folder: $egnyte_foundfolder"
                }
            } else {Write-Host "$user excluded per exclusions."}
        }
        ############ FIX TOP LEVEL PERMISSIONS #######
        foreach ($user in $egnyte_required_topfolder_permissions) {
            # Check if user is not in exclusions
            if (!$egnyte_exclusions.Contains($user.InputObject)) {
            #if nothing to compare, load whole list
                if ($egnyte_empty_topfolder_userpermissions -eq $true) {
                    if ($egnyte_foundfolder -like "*Projects Drive*") {
                            $egnyte_topfolder_permissions_array += [ordered]@{$user = "Full";}
                        }
                    if ($egnyte_foundfolder -like "*Projects Archive*") {
                            $egnyte_topfolder_permissions_array += [ordered]@{$user = "Viewer";}
                        }
                    Write-Host "Applying top level permissions for: $user to folder: $wmj_clientname"
                }
                #if user shows as needing added, add user
                if ($user.sideindicator -eq "=>") {
                        #create array, and add 1 user at a time, cycling through
                    if ($egnyte_foundfolder -like "*Projects Drive*") {
                            $egnyte_topfolder_permissions_array += [ordered]@{$user.InputObject = "Full";}
                        }
                    if ($egnyte_foundfolder -like "*Projects Archive*") {
                            $egnyte_topfolder_permissions_array += [ordered]@{$user.InputObject = "Viewer";}
                        }
                    Write-Host "Applying top level permissions for: $($user.InputObject) to folder: $wmj_clientname"
                }
                if ($user.InputObject -eq $null) {
                    Write-Host "No InputObject detected."
                }
            }
        }
        $egnyte_permission_requestdata = New-Object PSObject
                    $egnyte_permission_requestdata | Add-Member -MemberType NoteProperty -Name 'userPerms' -Value $egnyte_permissions_array
                    $egnyte_permission_requestdata = $egnyte_permission_requestdata | ConvertTo-JSON -Depth 99
        Invoke-RestMethod -URI $egnyte_permissions_uri -Method POST -Headers $egnyte_headers -Body $egnyte_permission_requestdata -ContentType "application/json"
        Start-Sleep -Seconds 1
        Write-Host "Project Folder Permission Applied"
        $egnyte_topfolder_permission_requestdata = New-Object PSObject
                    $egnyte_topfolder_permission_requestdata | Add-Member -MemberType NoteProperty -Name 'userPerms' -Value $egnyte_topfolder_permissions_array
                    $egnyte_topfolder_permission_requestdata =  $egnyte_topfolder_permission_requestdata | ConvertTo-JSON -Depth 99
        Invoke-RestMethod -URI $egnyte_topfolder_permission_uri -Method POST -Headers $egnyte_headers -Body $egnyte_topfolder_permission_requestdata -ContentType "application/json"
        Start-Sleep -Seconds 1
        Write-Host "Top Level Folder Permissions Applied"
        }
    } else {
        Write-Host "Did not find a folder."
    }
}