# Moves PAY-101 and PAY-102 to Done and completes the active sprint on the PAY board.
# Credentials come from environment variables or prompts; nothing is stored on disk.
#   $env:JIRA_SITE  = "https://<your-site>.atlassian.net"
#   $env:JIRA_EMAIL = "<your Atlassian login email>"
#   $env:JIRA_TOKEN = "<API token from https://id.atlassian.com/manage-profile/security/api-tokens>"
# Usage:
#   .\jira\complete-sprint.ps1 -DryRun   # show what would change
#   .\jira\complete-sprint.ps1           # apply
param(
    [string]$Project = "PAY",
    [string[]]$Issues = @("PAY-101", "PAY-102"),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$site  = if ($env:JIRA_SITE)  { $env:JIRA_SITE.TrimEnd('/') } else { (Read-Host "Jira site (https://xxx.atlassian.net)").TrimEnd('/') }
$email = if ($env:JIRA_EMAIL) { $env:JIRA_EMAIL } else { Read-Host "Atlassian email" }
if ($env:JIRA_TOKEN) {
    $token = $env:JIRA_TOKEN
} else {
    $secure = Read-Host "API token" -AsSecureString
    $token  = [Runtime.InteropServices.Marshal]::PtrToStringAuth([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

$auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${token}"))
$headers = @{ Authorization = "Basic $auth"; Accept = "application/json" }

function Invoke-Jira([string]$Method, [string]$Path, $Body = $null) {
    $params = @{ Method = $Method; Uri = "$site$Path"; Headers = $headers }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 5)
    }
    Invoke-RestMethod @params
}

# 1. Board and active sprint
$board = (Invoke-Jira GET "/rest/agile/1.0/board?projectKeyOrId=$Project").values | Select-Object -First 1
if (-not $board) { throw "No board found for project $Project" }
Write-Host "Board : $($board.name) (id $($board.id))"

$sprint = (Invoke-Jira GET "/rest/agile/1.0/board/$($board.id)/sprint?state=active").values | Select-Object -First 1
if (-not $sprint) { throw "No active sprint on board $($board.id). Start the sprint in Jira first." }
Write-Host "Sprint: $($sprint.name) (id $($sprint.id), state $($sprint.state))"

# 2. Transition each issue to a status in the Done category
foreach ($key in $Issues) {
    $issue  = Invoke-Jira GET "/rest/api/3/issue/${key}?fields=status"
    $status = $issue.fields.status
    if ($status.statusCategory.key -eq "done") {
        Write-Host "$key already '$($status.name)'"
        continue
    }
    $done = (Invoke-Jira GET "/rest/api/3/issue/$key/transitions").transitions |
        Where-Object { $_.to.statusCategory.key -eq "done" } | Select-Object -First 1
    if (-not $done) { throw "$key has no transition to a Done status from '$($status.name)'" }
    if ($DryRun) {
        Write-Host "[dry-run] $key '$($status.name)' -> '$($done.to.name)'"
    } else {
        Invoke-Jira POST "/rest/api/3/issue/$key/transitions" @{ transition = @{ id = $done.id } } | Out-Null
        Write-Host "$key '$($status.name)' -> '$($done.to.name)'"
    }
}

# 3. Complete the sprint
if ($DryRun) {
    Write-Host "[dry-run] would complete sprint '$($sprint.name)'"
} else {
    Invoke-Jira POST "/rest/agile/1.0/sprint/$($sprint.id)" @{ state = "closed" } | Out-Null
}

# 4. Verify
Write-Host "`n--- Verification"
foreach ($key in $Issues) {
    $s = (Invoke-Jira GET "/rest/api/3/issue/${key}?fields=status").fields.status
    Write-Host ("{0,-8} {1} ({2})" -f $key, $s.name, $s.statusCategory.key)
}
$after = Invoke-Jira GET "/rest/agile/1.0/sprint/$($sprint.id)"
Write-Host "Sprint '$($after.name)' state: $($after.state)"
Write-Host "Burndown: $site/jira/software/projects/$Project/boards/$($board.id)/reports/burndown-chart"
