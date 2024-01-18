#################################################################
#
#                                                       
# Filename: egnyte_problem_projects.ps1                              
# Use: Pull latest egnyte_archive.csv report and push failed interactions to Slack       
# Author: DM       
# Requires: 
# - Powershell 5.1 Compliance
# - Running from REDACTED
# 
#################################################################
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
    Invoke-WebRequest -URI $slack_uri -Method "POST" -Body $body -ContentType 'application/json' | Out-Null
}

#########################
# GET REPORT AND SORT   #
#########################
$lwd = "REDACTED"
# Find and get the newest .csv file
$report_fp = ".\" + (Get-ChildItem $lwd -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name

# Set our report to the newest .csv
$report = Import-CSV -Path $report_fp | Where-Object post_successful -like "*FALSE*" | Select-Object project_number,post_error
[string[]] $report_string = ""
$report_string = $report | Out-String -Width 999

# Format it to make it look pretty, blame Slack for not having the PowerShell end all be all handling of text
$pwsh_nl1 = [char]0x0D
$pwsh_nl2 = [char]0x0A
$report_string = $report_string -split "----------"
$report_string = $report_string[2]
$report_string = $report_string -replace '(\d+)-(\w+)-(\d+)','$1-$2-$3:' -replace "   ","" -replace "/Shared/","$pwsh_nl1$pwsh_nl2/Shared/" -replace ":(\w)",': $1'
$report_projectlist = $report_string -split "$pwsh_nl1$pwsh_nl2"

# Send the report to Slack
Get-CurrentDate
$cDateTime = Get-Date -Date $tCurrentTime 
$cDateTime = $cDateTime -replace "\n",""
Update-Slack "Here's the list of problem projects to address for $cDateTime`:
CURRENTLY LISTED: $($report.length) 

Problem Projects List:"

foreach ($project in $report_projectlist) {
    if ($null -eq $project) { continue }
    Update-Slack "$project"
    Start-Sleep .5
}