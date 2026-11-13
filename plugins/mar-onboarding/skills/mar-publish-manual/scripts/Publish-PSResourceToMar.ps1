#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes a PowerShell module (folder or .nupkg) to an MAR-onboarded ACR as a PSResource.
.DESCRIPTION
    Ensures Microsoft.PowerShell.PSResourceGet >= 1.2.0, registers the ACR as a ContainerRegistry
    PSResource repository, and runs Publish-PSResource with -ModulePrefix.
    You must already be signed in to Azure (az login / Connect-AzAccount) with AcrPush on the registry.
.EXAMPLE
    ./Publish-PSResourceToMar.ps1 -Path ./out/MyModule -RegistryName mymoduleacr
.EXAMPLE
    ./Publish-PSResourceToMar.ps1 -Path ./out/mymodule.1.2.3.nupkg -RegistryName mymoduleacr -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [ValidatePattern('^[a-zA-Z0-9]{5,50}$')] [string] $RegistryName,
    [string] $ModulePrefix = 'psresource',
    [string] $RepositoryName = $RegistryName,
    # Re-register the repository and re-push (needed if the module was pushed before MAR onboarding).
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$minVersion = [version]'1.2.0'
$moduleName = 'Microsoft.PowerShell.PSResourceGet'

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path

$installed = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
if (-not $installed -or $installed.Version -lt $minVersion) {
    if ($PSCmdlet.ShouldProcess($moduleName, "Install version >= $minVersion from PSGallery")) {
        if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
            Install-PSResource -Name $moduleName -Version "[$minVersion,)" -Repository PSGallery -Scope CurrentUser -TrustRepository
        } else {
            Install-Module -Name $moduleName -MinimumVersion $minVersion -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
        }
    }
}
Import-Module $moduleName -MinimumVersion $minVersion -Force

$uri = "https://$($RegistryName.ToLower()).azurecr.io"
$repo = Get-PSResourceRepository -Name $RepositoryName -ErrorAction SilentlyContinue
if ($repo -and $Force) {
    Unregister-PSResourceRepository -Name $RepositoryName
    $repo = $null
}
if (-not $repo) {
    if ($PSCmdlet.ShouldProcess($uri, "Register PSResource repository '$RepositoryName'")) {
        Register-PSResourceRepository -Name $RepositoryName -Uri $uri -ApiVersion ContainerRegistry -Trusted
    }
} elseif ($repo.Uri.AbsoluteUri.TrimEnd('/') -ne $uri) {
    throw "Repository '$RepositoryName' is already registered with Uri '$($repo.Uri)'. Use -RepositoryName or -Force."
}

$publishParams = @{
    Repository   = $RepositoryName
    ModulePrefix = $ModulePrefix
}
if ($resolvedPath -like '*.nupkg') {
    $publishParams.NupkgPath = $resolvedPath
    $pkgName = ([IO.Path]::GetFileNameWithoutExtension($resolvedPath) -replace '\.\d+(\.\d+){1,3}(-[\w\.]+)?$', '')
} else {
    $publishParams.Path = $resolvedPath
    $pkgName = Split-Path $resolvedPath -Leaf
}

$target = "$uri/$ModulePrefix/$pkgName".ToLower()
if ($PSCmdlet.ShouldProcess($target, 'Publish-PSResource')) {
    Publish-PSResource @publishParams -Verbose:$VerbosePreference
    Write-Host "Published '$pkgName' to $target"
    Write-Host "Next: verify with ../../mar-verify-publishing/scripts/Test-MarPublish.ps1 -RegistryName $RegistryName -ModuleName $pkgName"
}
