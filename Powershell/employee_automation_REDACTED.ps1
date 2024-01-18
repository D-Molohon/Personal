### TO-DO ###

# System.Web is how we generate a more random password
# Only available in Windows Powershell (5.1 or lower) 
[System.Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
# For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 
# SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Adding Credential Manager to deal with Windows Credential importing
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

# Slack Logging via #it-onboarding-automation channel webhook (to be generated)
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

Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime 
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Starting Employee Onboarding Automation, Timestamp: $cDateTime"

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
$e_REDACTED_key=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_jc_key=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
Start-Sleep 1
$e_egnyte_hraccesstoken=(Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $github_headers).Content.replace("$bad_char","") | ConvertTo-SecureString -Key $aeskey
# Use the encrypted String in a PSCredential Object...
$REDACTED_key_credential = New-Object System.Management.Automation.PsCredential("placeholder1", $e_REDACTED_key)
$jc_key_credential = New-Object System.Management.Automation.PsCredential("placeholder2", $e_jc_key)
$egnyte_hraccesstoken_credential = New-Object System.Management.Automation.PsCredential("placeholder3", $e_egnyte_hraccesstoken)
# Grab the password part of the object we just made, which was decrypted and is stored in the PsCredential Object
$REDACTED_key = $REDACTED_key_credential.GetNetworkCredential().password
$jc_key = $jc_key_credential.GetNetworkCredential().password
$egnyte_hraccesstoken = $egnyte_hraccesstoken_credential.GetNetworkCredential().password

#########################
# REDACTED INFO            #
#########################
$pass="placeholder" # This can be anything, but REDACTED is mainly looking for the Form's API key.
$pair="$($REDACTED_key):$($pass)"
$e_pair = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
$REDACTED_headers = @{ Authorization = "Basic $e_pair" }

#########################
# JUMPCLOUD INFO        #
#########################
$jc_headers = @{"x-api-key" = $jc_key}
$jc_api_url = "https://console.jumpcloud.com/api/"
$jc_api_usergroups_url = $jc_api_url + "v2/usergroups"
$jc_api_users_url = $jc_api_url + "systemusers"

class JC_User { # Info in JC_User is imported from the REDACTED form (field ID's are viewable in the Form's API information)
    [string]$username
    [string]$email
    [string]$state = "ACTIVATED"  
    [string]$password
    [string]$jobTitle
    [string]$firstName
    [string]$lastName
    [string]$company
    [string]$employeeType 
    [string]$department
    [string]$tempType
    [boolean]$isManager
    [boolean]$isExec
    [boolean]$isOnSite
}
$jc_api_get_usergroups_url = $jc_api_usergroups_url + "?limit=100&skip=0"
$jc_usergroups = $(Invoke-WebRequest -URI $jc_api_get_usergroups_url -Method GET -Headers $jc_headers)
$jc_usergroups = $jc_usergroups.Content | ConvertFrom-Json

#########################
# EGNYTE INFO        #
#########################
$egnyte_headers = @{ Authorization = "Bearer $egnyte_hraccesstoken" }
$egnyte_api_createfolder = @{ action = 'add_folder' } | ConvertTo-JSON

#########################
# FLAG CHECK            #
#########################
$flagDt=(Get-ChildItem "REDACTED").LastWriteTime
remove-item "REDACTED"
new-item "REDACTED"

#########################
# REDACTED IMPORT          #
#########################
# Invoke-WebRequest the REDACTED form, grab the JSON content and store it
$REDACTED_response = Invoke-WebRequest -URI "REDACTED" -Method GET -Headers $REDACTED_headers
$REDACTED_entries = $REDACTED_response.Content | ConvertFrom-Json

# Cut what we don't need (anything older than 1 day, usually)
if ($null -ne $flagDt) {
    Update-Slack "Using employee_automation.flg for date and time baseline, which is $flagDt."
    $REDACTED_entries_postsort = $REDACTED_entries.Entries | Where-Object {(Get-Date $_.DateCreated) -ge $flagDt} | Sort-Object -Property DateCreated -Descending
} else {
    Update-Slack "No flag found. Using current date/time minus 1 day as the baseline."
    $REDACTED_entries_postsort = $REDACTED_entries.Entries | Where-Object {(Get-Date $_.DateCreated) -gt (Get-Date -Date $tCurrentTime.AddDays(-1))} | Sort-Object -Property DateCreated -Descending
}

foreach ($entry in $REDACTED_entries_postsort) { # Loop through each REDACTED entry, performing the logic of account creation
    Update-Slack "New entry found - Creating data for: $($entry.Field1) $($entry.Field2)"
    $REDACTED = $entry
    $user = [JC_User]::new()
    $user.username = $REDACTED.Field1.Substring(0,1) + $REDACTED.Field2
    $user.password = "REDACTED_" + [System.Web.Security.Membership]::GeneratePassword(6,2) # Generate a Random Password using the System.Web assembly we loaded using Reflection at the top
    $user.jobTitle = $REDACTED.Field263
    $user.firstName = $REDACTED.Field1
    $user.lastName = $REDACTED.Field2
    $user.company = $REDACTED.Field7
    $user.employeeType = $REDACTED.Field126 # Note that there is a second job title entry after employeeType in REDACTED, same as the first, listed when posting to JumpCloud
    $user.department = $(if ($REDACTED.Field7 -like "REDACTED1") {$REDACTED.Field5} else {$REDACTED.Field12}) # REDACTED1 and REDACTED2 have separate department options, REDACTED1 is Field5, REDACTED2 is Field12.
    $user.tempType = $(if ($REDACTED.Field126 -like "Temporary") {$REDACTED.Field127})
    $user.isManager = $(if ($REDACTED.Field123 -like "Yes" -or $REDACTED.Field124 -like "Yes") {$True} else {$False}) # Checking if "In Management role" is "Yes"
    $user.isExec = $(if ($REDACTED.Field13 -like "Executive" -or $REDACTED.Field17 -like "Executive") {$True} else {$False}) # This is the added layer for execs, not all managers are execs, but all execs are managers.
    $user.isOnSite = $(if ($REDACTED.Field10 -like "REDACTED") {$True} else {$False})
    
    while ($user.firstName -match '\W$') { # Format the First and Last name to remove any additional whitespace additions on the end  
        $fname = $user.firstName -split '\W$'
        $user.firstName = $fname[0]
    }
    while ($user.lastName -match '\W$') {        
        $lname = $user.lastName -split '\W$'
        $user.lastName = $lname[0]
    }

    $jc_body = @{ ## Build the default POST to https://console.jumpcloud.com/api/systemusers
        username=$user.username
        state="ACTIVATED"
        password=$user.password
        jobtitle=$user.jobTitle
        firstname=$user.firstName
        lastname=$user.lastName
        company=$user.company
        department=$user.department
    }

    $egnyte_topfolder_creation_array = @( # Build the Egnyte REDACTED folder flow with the user specific information
        "REDACTED"
    )

    ##########################
    # REDACTED1 EMPLOYEE FLOW      #
    ##########################
    if ($user.company -like "REDACTED1" -And $user.department -notlike "REDACTED3" -And $user.employeeType -like "Staff") { ## JUMPCLOUD FLOW
        $user.email = $REDACTED.Field1.Substring(0,1) + $REDACTED.Field2 + "REDACTED"
        $jc_body += @{ ## Then specify some extra necessary info, like our specific email and employee type
            email=$user.email
            employeeType="Full Time"
        }
        $jc_body = $jc_body | ConvertTo-Json
        $jc_makeuser = $(Invoke-WebRequest -URI $jc_api_users_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8')
        Start-Sleep 1
        Update-Slack "-- NEW REDACTED1 USER CREATED --`n Name: $($user.firstname) $($user.lastname)`n Username: $($user.username)`n Email: $($user.email)`n Company: $($user.company)`n Department: $($user.department)`n Type: $($user.employeeType)`n Password: $($user.password)`n ------------------------------------------"
        $jc_userinfo = $jc_makeuser.Content | ConvertFrom-Json
        $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED1" # REDACTED
        $jc_body = @{
            "id"=$($jc_userinfo.id)
            "op"="add" 
            "attributes"={}
            "type"="user"
        } | ConvertTo-Json
        Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8'
        Update-Slack "$($user.username) added to: REDACTED1"
        Start-Sleep 1

        foreach ($egnyte_topfolder_creation_uri in $egnyte_topfolder_creation_array) { ## EGNYTE FLOW
            Invoke-WebRequest -URI $egnyte_topfolder_creation_uri -Method "POST" -Body $egnyte_api_createfolder -Headers $egnyte_headers -ContentType 'application/json; charset=UTF-8'
            Start-Sleep -Milliseconds 500
            Update-Slack "Created folder: $egnyte_topfolder_creation_uri"
        }
    }

    ##########################
    # REDACTED2 EMPLOYEES FLOW #
    ##########################
    if ($user.company -like "REDACTED2" -And $user.employeeType -like "Staff") { ## JUMPCLOUD FLOW
        $user.email = $REDACTED.Field1.Substring(0,1) + $REDACTED.Field2 + "REDACTED2"
        $jc_body += @{ ## Then specify some extra necessary info, like our specific email and employee type
            email=$user.email
            employeeType="Full Time"
        }
        $jc_makeuser = $(Invoke-WebRequest -URI $jc_api_users_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8')
        Update-Slack "-- NEW REDACTED2 USER CREATED --`n Name: $($user.firstname) $($user.lastname)`n Username: $($user.username)`n Email: $($user.email)`n Company: $($user.company)`n Department: $($user.department)`n Type: $($user.employeeType)`n Password: $($user.password)`n ------------------------------------------"
        $jc_userinfo = $jc_makeuser.Content | ConvertFrom-Json
        $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED2" # REDACTED
        $jc_body = @{ 
            "id"=$($jc_userinfo.id)
            "op"="add" 
            "attributes"={}
            "type"="user"
        } | ConvertTo-Json
        Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
        Update-Slack "$($user.username) added to: REDACTED2"
        Start-Sleep 1

        foreach ($egnyte_topfolder_creation_uri in $egnyte_topfolder_creation_array) { ## EGNYTE FLOW
            Invoke-WebRequest -URI $egnyte_topfolder_creation_uri -Method "POST" -Body $egnyte_api_createfolder -Headers $egnyte_headers -ContentType 'application/json; charset=UTF-8'
            Start-Sleep -Milliseconds 500
            Update-Slack "Created folder: $egnyte_topfolder_creation_uri"
        }
    }

    ##########################
    # REDACTED3 EMPLOYEES FLOW #
    ##########################
    if ($user.company -like "REDACTED1" -And $user.department -like "REDACTED3" -And $user.employeeType -like "Staff") { ## JUMPCLOUD FLOW
        $user.email = $REDACTED.Field1.Substring(0,1) + $REDACTED.Field2 + "REDACTED"
        $jc_body += @{ ## Then specify some extra necessary info, like our specific email and employee type
            email=$user.email
            employeeType="Full Time"
        }
        $jc_makeuser = $(Invoke-WebRequest -URI $jc_api_users_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8')
        Update-Slack "-- NEW REDACTED3 USER CREATED --`n Name: $($user.firstname) $($user.lastname)`n Username: $($user.username)`n Email: $($user.email)`n Company: $($user.company)`n Department: $($user.department)`n Type: $($user.employeeType)`n Password: $($user.password)`n ------------------------------------------"
        $jc_userinfo = $jc_makeuser.Content | ConvertFrom-Json
        $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED" # REDACTED1
        $jc_body = @{
            "id"=$($jc_userinfo.id)
            "op"="add" 
            "attributes"={}
            "type"="user"
        } | ConvertTo-Json
        Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
        Update-Slack "$($user.username) added to: REDACTED"
        Start-Sleep 1
        ### Technically REDACTED3 is a Department, this is only really here in case we need to manually add to the REDACTED3 group ###
        # $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED3" # REDACTED
        # Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8'
        # Start-Sleep 1

        foreach ($egnyte_topfolder_creation_uri in $egnyte_topfolder_creation_array) { ## EGNYTE FLOW
            Invoke-WebRequest -URI $egnyte_topfolder_creation_uri -Method "POST" -Body $egnyte_api_createfolder -Headers $egnyte_headers -ContentType 'application/json; charset=UTF-8'
            Start-Sleep -Milliseconds 500
            Update-Slack "Created folder: $egnyte_topfolder_creation_uri"
        }
    }

    ##########################
    # TEMP EMPLOYEES FLOW    #
    ##########################
    if ($user.employeeType -like "Temporary") { ## So NOT a full time employee, needs additional information
        $jc_body += @{
            email=$user.email
            employeeType="Temporary"
        }
        if ($user.tempType -like "Contractor") { ## CONTRACTOR
            $jc_makeuser = $(Invoke-WebRequest -URI $jc_api_users_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8')
            $jc_userinfo = $jc_makeuser.Content | ConvertFrom-Json
            Update-Slack "-- NEW CONTRACTOR CREATED --`n Name: $($user.firstname) $($user.lastname)`n Username: $($user.username)`n Email: $($user.email)`n Company: $($user.company)`n Department: $($user.department)`n Type: $($user.employeeType)`n Password: $($user.password)`n ------------------------------------------"
        } elseif ($user.tempType -like "Freelancer") { ## FREELANCER
            $jc_makeuser = $(Invoke-WebRequest -URI $jc_api_users_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8')
            $jc_userinfo = $jc_makeuser.Content | ConvertFrom-Json
            Update-Slack "-- NEW FREELANCER CREATED --`n Name: $($user.firstname) $($user.lastname)`n Username: $($user.username)`n Email: $($user.email)`n Company: $($user.company)`n Department: $($user.department)`n Type: $($user.employeeType)`n Password: $($user.password)`n ------------------------------------------"
        } elseif ($user.tempType -like "Intern") { ## INTERN
            $jc_makeuser = $(Invoke-WebRequest -URI $jc_api_users_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8')
            $jc_userinfo = $jc_makeuser.Content | ConvertFrom-Json
            Update-Slack "-- NEW INTERN CREATED --`n Name: $($user.firstname) $($user.lastname)`n Username: $($user.username)`n Email: $($user.email)`n Company: $($user.company)`n Department: $($user.department)`n Type: $($user.employeeType)`n Password: $($user.password)`n ------------------------------------------"
            
            foreach ($egnyte_topfolder_creation_uri in $egnyte_topfolder_creation_array) { ## EGNYTE FLOW
                Invoke-WebRequest -URI $egnyte_topfolder_creation_uri -Method "POST" -Body $egnyte_api_createfolder -Headers $egnyte_headers -ContentType 'application/json; charset=UTF-8'
                Start-Sleep -Milliseconds 500
                Update-Slack "Created folder: $egnyte_topfolder_creation_uri"
            }
        } else { ## IF IT AIN'T ANY OF EM
            Update-Slack "It shouldn't be possible to even get here in the script. How did we manage this? Well...
            User's Info: $user"
            exit
        }
        foreach ($group in $jc_usergroups) { ## Now add to the appropriate REDACTED Group in JumpCloud
            if ($group.name -like "*$($user.tempType)*") {
                $jc_api_usergroup_add_url = $jc_api_usergroups_url + "/$($group.id)/members"
                $jc_body = @{
                    "id"=$($jc_userinfo.id)
                    "op"="add" 
                    "attributes"={}
                    "type"="user"
                } | ConvertTo-Json
                Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
                Update-Slack "$($user.username) added to: REDACTED"
                Start-Sleep 1
            }
        }
    }
    ##########################
    # DEPARTMENT > GROUP ADD #
    ##########################
    $group_check = $($user.department -split '\W') ## Breakdown the department into usable sections that we can sift through quickly
    if ($group_check[0] -like "REDACTED") { ## This is because the REDACTED Form does not expand the name for either REDACTED or REDACTED, but the group in JumpCloud is expanded 
        $group_check[0] = "REDACTED"
    } elseif ($group_check[0] -like "REDACTED") {
        $group_check[0] = "REDACTED"
    }
    if ($user.employeeType -like "Staff" -Or $user.tempType -notlike "Freelancer") { ## Only Freelancers are excluded from being added to Department groups, for now.
        foreach ($group in $jc_usergroups) {
            if ($group.name -like "*$($group_check[0])*") { ## Find the right group for the department
                $jc_api_usergroup_add_url = $jc_api_usergroups_url + "/$($group.id)/members"
                Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
                Update-Slack "$($user.username) added to the JumpCloud department group for: $($group_check[0])"
                Start-Sleep 1
            } elseif ($user.department -like "REDACTED") { ## REDACTED is both, push the user to REDACTED AND REDACTED
                $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED" # REDACTED
                Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
                Update-Slack "$($user.username) added to: REDACTED"
                Start-Sleep 1
                $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED" # REDACTED
                Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
                Update-Slack "$($user.username) added to: REDACTED"
                Start-Sleep 1
            }
        }
    }
    if ($user.isExec) { ## Executive Groups
        if ($user.company -like "REDACTED2") { # Are we REDACTED?
            $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED2" # REDACTED
            Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
            Update-Slack "$($user.username) added to: REDACTED2"
            Start-Sleep 1
        } else { # No? Then we're REDACTED1
            $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED1" # REDACTED
            Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
            Update-Slack "$($user.username) added to: REDACTED1"
            Start-Sleep 1
        }
    }
    if ($user.isManager) { ## Manager Groups
        if ($user.company -like "*REDACTED2*") { # Are we REDACTED2?
            $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED2" # REDACTED
            Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
            Update-Slack "$($user.username) added to: REDACTED2"
            Start-Sleep 1
        } else { # No? Then we're REDACTED1
            $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED1" # REDACTED
            Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
            Update-Slack "$($user.username) added to: REDACTED1"
            Start-Sleep 1
        }
    }
    if ($user.isOnSite) { ## REDACTED Group for REDACTED and REDACTED
        $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED1" # REDACTED
        Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
        Update-Slack "$($user.username) added to: REDACTED"
        Start-Sleep 1
        $jc_api_usergroup_add_url = $jc_api_usergroups_url + "REDACTED1" # REDACTED
        Invoke-WebRequest -URI $jc_api_usergroup_add_url -Method POST -Headers $jc_headers -Body $jc_body -ContentType 'application/json; charset=UTF-8' | Out-Null
        Update-Slack "$($user.username) added to: REDACTED"
    }
    Clear-Variable REDACTED
    Clear-Variable user
}

Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime 
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Stopping Employee Onboarding Automation, Timestamp: $cDateTime"