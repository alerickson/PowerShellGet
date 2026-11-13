#Requires -Version 7.0
<#
.SYNOPSIS
    Emits the MCR "syndications" block that replicates a PSResource to the Air-Gapped Clouds,
    or validates that a MCR onboarding YAML file contains it for every module entry.
.EXAMPLE
    ./Get-MarSyndicationBlock.ps1 -Indent 4
.EXAMPLE
    ./Get-MarSyndicationBlock.ps1 -ValidatePath ./teams/myteam/mymodule.yml -ExpectedEntryCount 2
#>
[CmdletBinding(DefaultParameterSetName = 'Emit')]
param(
    [Parameter(ParameterSetName = 'Emit')] [ValidateRange(0, 40)] [int] $Indent = 0,
    [Parameter(ParameterSetName = 'Validate', Mandatory)] [string] $ValidatePath,
    [Parameter(ParameterSetName = 'Validate')] [int] $ExpectedEntryCount = 1
)

$ErrorActionPreference = 'Stop'

$block = @'
syndications:
  - type: cloud
    destinations:
      - usnat
      - ussec
    tags:
      - source: /^(0|[1-9]\d*)(\.(0|[1-9]\d*)){0,3}$/
'@

if ($PSCmdlet.ParameterSetName -eq 'Emit') {
    $pad = ' ' * $Indent
    return ($block -split "`r?`n" | ForEach-Object { "$pad$_" }) -join [Environment]::NewLine
}

$content = Get-Content -LiteralPath $ValidatePath -Raw
$lines = $content -split "`r?`n"
$found = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch '^(\s*)syndications:\s*$') { continue }
    $baseIndent = $Matches[1].Length
    $section = [System.Collections.Generic.List[string]]::new()
    for ($j = $i + 1; $j -lt $lines.Count; $j++) {
        $l = $lines[$j]
        if ($l.Trim() -and (($l.Length - $l.TrimStart().Length) -le $baseIndent)) { break }
        $section.Add($l.Trim())
    }
    $text = $section -join "`n"
    $ok = ($text -match '(?m)^-?\s*type:\s*cloud\s*$') -and
          ($text -match '(?m)^-\s*usnat\s*$') -and
          ($text -match '(?m)^-\s*ussec\s*$') -and
          ($text -match [regex]::Escape('source: /^(0|[1-9]\d*)(\.(0|[1-9]\d*)){0,3}$/'))
    if ($ok) { $found++ } else { Write-Warning "Incomplete syndications block at line $($i + 1) of $ValidatePath" }
}

$result = [pscustomobject]@{
    Path                    = $ValidatePath
    ValidSyndicationBlocks  = $found
    ExpectedEntryCount      = $ExpectedEntryCount
    Passed                  = ($found -ge $ExpectedEntryCount)
}
if (-not $result.Passed) {
    Write-Warning "Expected $ExpectedEntryCount valid syndications block(s) but found $found."
}
$result
