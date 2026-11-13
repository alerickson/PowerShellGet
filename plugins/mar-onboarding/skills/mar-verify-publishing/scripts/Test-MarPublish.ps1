#Requires -Version 7.0
<#
.SYNOPSIS
    Verifies a PSResource was pushed to an ACR as <visibility tag>/psresource/<ModuleName> with the expected
    version tag, and optionally shows recent ACR webhook activity to help troubleshoot MAR syndication.
.EXAMPLE
    ./Test-MarPublish.ps1 -RegistryName mymoduleacr -ModuleName MyModule -Version 1.2.3 -IncludeWebhookEvents
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RegistryName,
    [Parameter(Mandatory)] [string] $ModuleName,
    [string] $Version,
    [string] $ModulePrefix = 'psresource',
    [switch] $IncludeWebhookEvents
)

$ErrorActionPreference = 'Stop'

function Invoke-Az {
    $out = & az @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed: $out" }
    $out
}

$suffix = "$ModulePrefix/$ModuleName".ToLower()
$repos = Invoke-Az acr repository list --name $RegistryName --output json | ConvertFrom-Json
$matched = @($repos | Where-Object { $_.ToLower() -eq $suffix -or $_.ToLower().EndsWith("/$suffix") })

$tags = @()
foreach ($r in $matched) {
    $tags += Invoke-Az acr repository show-tags --name $RegistryName --repository $r --output json | ConvertFrom-Json |
        ForEach-Object { [pscustomobject]@{ Repository = $r; Tag = $_ } }
}

$versionFound = if ($Version) { [bool]($tags | Where-Object Tag -eq $Version) } else { $null }

$result = [pscustomobject]@{
    Registry          = $RegistryName
    ExpectedPath      = "<visibility tag>/$suffix"
    RepositoriesFound = $matched
    Tags              = ($tags.Tag | Sort-Object -Unique)
    ExpectedVersion   = $Version
    VersionFound      = $versionFound
    Passed            = ($matched.Count -gt 0) -and ($versionFound -ne $false)
    StatusPortal      = 'https://status-portal.mscr.io/'
}

if ($matched.Count -eq 0) {
    Write-Warning "No repository matching '*$suffix' found in '$RegistryName'. Repositories: $($repos -join ', ')"
} elseif ($versionFound -eq $false) {
    Write-Warning "Version tag '$Version' not found. Tags present: $($result.Tags -join ', ')"
}

if ($IncludeWebhookEvents) {
    $webhooks = Invoke-Az acr webhook list --registry $RegistryName --output json | ConvertFrom-Json
    $events = foreach ($wh in $webhooks) {
        $list = & az acr webhook list-events --registry $RegistryName --name $wh.name --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $list) { continue }
        $list | ConvertFrom-Json | Select-Object -First 10 | ForEach-Object {
            [pscustomobject]@{
                Webhook    = $wh.name
                Timestamp  = $_.eventRequestMessage.content.timestamp
                Action     = $_.eventRequestMessage.content.action
                Repository = $_.eventRequestMessage.content.target.repository
                Tag        = $_.eventRequestMessage.content.target.tag
                StatusCode = $_.eventResponseMessage.statusCode
            }
        }
    }
    $result | Add-Member -NotePropertyName WebhookEvents -NotePropertyValue @($events)
}

$result
