#Requires -Version 7.0
<#
.SYNOPSIS
    Creates (or reuses) an Azure Container Registry for publishing a PSResource to MAR.
.EXAMPLE
    ./New-MarAcr.ps1 -SubscriptionId 0000-... -ResourceGroup rg-mymodule -RegistryName mymoduleacr -Location westus2
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [ValidatePattern('^[a-zA-Z0-9]{5,50}$')] [string] $RegistryName,
    [Parameter(Mandatory)] [string] $Location,
    [ValidateSet('Basic', 'Standard', 'Premium')] [string] $Sku = 'Premium'
)

$ErrorActionPreference = 'Stop'

function Invoke-Az {
    $out = & az @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed: $out" }
    $out
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) is required. Install it from https://aka.ms/installazurecli and run az login.'
}

Invoke-Az account set --subscription $SubscriptionId | Out-Null

if ((Invoke-Az group exists --name $ResourceGroup) -ne 'true') {
    if ($PSCmdlet.ShouldProcess($ResourceGroup, 'Create resource group')) {
        Invoke-Az group create --name $ResourceGroup --location $Location --output none | Out-Null
    }
}

$existing = & az acr show --name $RegistryName --resource-group $ResourceGroup --output json 2>$null
if ($LASTEXITCODE -eq 0 -and $existing) {
    Write-Host "ACR '$RegistryName' already exists; reusing it."
    $acr = $existing | ConvertFrom-Json
} elseif ($PSCmdlet.ShouldProcess($RegistryName, "Create ACR ($Sku)")) {
    $nameCheck = Invoke-Az acr check-name --name $RegistryName --output json | ConvertFrom-Json
    if (-not $nameCheck.nameAvailable) { throw "ACR name '$RegistryName' is not available: $($nameCheck.message)" }
    $acr = Invoke-Az acr create --name $RegistryName --resource-group $ResourceGroup --location $Location --sku $Sku --output json | ConvertFrom-Json
}

if ($acr) {
    [pscustomobject]@{
        Name        = $acr.name
        LoginServer = $acr.loginServer
        ResourceId  = $acr.id
        Sku         = $acr.sku.name
        Location    = $acr.location
    }
}
