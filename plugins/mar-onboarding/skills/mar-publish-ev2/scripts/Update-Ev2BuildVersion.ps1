#Requires -Version 7.0
<#
.SYNOPSIS
    Bumps the Ev2 artifact version in buildVer.txt so Ev2 registers (and rolls out) the new artifact.
.EXAMPLE
    ./Update-Ev2BuildVersion.ps1 -Path ./EV2Specs/ServiceGroupRoot/buildVer.txt
.EXAMPLE
    ./Update-Ev2BuildVersion.ps1 -Path ./EV2Specs/ServiceGroupRoot/buildVer.txt -Version 1.2.0.0
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $Path,
    [version] $Version
)

$ErrorActionPreference = 'Stop'

$raw = (Get-Content -LiteralPath $Path -Raw).Trim()
$current = $null
if (-not [version]::TryParse($raw, [ref]$current)) {
    throw "buildVer.txt contains '$raw', which is not a valid version."
}

if (-not $Version) {
    $parts = $raw.Split('.') | ForEach-Object { [int]$_ }
    $parts[-1]++
    $Version = [version]($parts -join '.')
}

if ($Version -le $current) {
    throw "New version $Version must be greater than the current version $current."
}

if ($PSCmdlet.ShouldProcess($Path, "Update version $current -> $Version")) {
    Set-Content -LiteralPath $Path -Value $Version.ToString() -NoNewline
}

[pscustomobject]@{ Path = $Path; OldVersion = $current; NewVersion = $Version }
