<#                                                     
Filename: github_pull.ps1                              
Use: Pull RAW Content of script from GitHub to execute instead of storing script locally.
Author: DM       
Requires: 
- Powershell 5.1 Compliance

Instructions:
- Module "CredentialManager" installed (use this command to install: Install-Module -Name CredentialManager -Scope AllUsers)
- In Windows Credential Manager, under Windows Credentials > Generic Credentials >
Add a generic credential for "GitHub" with the password being the DMOLOHON token stored in the GitHub BitWarden entry. ("User name" field can be anything)
* This credential HAS to be stored on the User running the Task in Task Scheduler. This User CANNOT BE SYSTEM. (Not recommended to use the built-in Administrator, either.)
- Import the task from the backed up XML task file. (ex. TASK_EgnyteSync_GitHub)
* Make sure the user that's being used for the task has the Generic GitHub credential.
- Adjust Task Details/Frequency as needed.

WMJ API Guide: https://support.workamajig.com/hc/en-us/articles/360023007451-API-Overview
Egnyte API Guide: https://developers.egnyte.com/docs

06/28/23 - DM - Made this to securely and safely store/execute our Egnyte scripts from GitHub
This is as follows: "...\github_pull.ps1 -ScriptName "egnyte-sync""
This will access "REDACTED/main/egnyte-sync.ps1" and shape it into something executable
All that is needed is to match the script name as it shows up in GitHub.
#>
param(
    [Parameter(Mandatory=$True)]
    [string]$ScriptName 
)
# SET TLS TO 1.2 FOR ISSUES IN SOME API CALLS NOT COMPLETING
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# For using WebRequest instead of RestMethod, we need to turn off the progress bar to increase efficiency.
$ProgressPreference = 'SilentlyContinue' 

Import-Module -Name CredentialManager

$github_token_credential = Get-StoredCredential -Target GitHub

$github_token = $github_token_credential.GetNetworkCredential().password

$github_headers = @{ Authorization = "token $github_token" }

$github_ps1 = Invoke-WebRequest -URI "REDACTED/main/$ScriptName.ps1" -Method GET -Headers $github_headers

$SB = [Scriptblock]::Create($github_ps1.Content)
Invoke-Command -ScriptBlock $SB

# $job_result = Start-Job -Name $ScriptName -ScriptBlock $SB
# $job_id = $job_result.Id

# while ($job_result.State -like "*running*") {
#     Start-Sleep 30
#     $job_result = Get-Job $job_id
# }