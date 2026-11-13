#Requires -Version 7.0
<#
.SYNOPSIS
    Creates (or reuses) the managed identity used by the Ev2 pipeline to publish a PSResource to an ACR,
    grants it the required ACR roles, and optionally adds a Federated Identity Credential (needed for AME).
.EXAMPLE
    ./New-MarPublishIdentity.ps1 -SubscriptionId 0000-... -ResourceGroup rg-mymodule -IdentityName mi-mymodule-ev2 -RegistryName mymoduleacr -Location westus2
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $SubscriptionId,
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $IdentityName,
    [Parameter(Mandatory)] [string] $RegistryName,
    [Parameter(Mandatory)] [string] $Location,
    [string] $RegistryResourceGroup = $ResourceGroup,
    [string] $FederatedCredentialName,
    [string] $FederatedIssuer,
    [string] $FederatedSubject,
    [string] $FederatedAudience = 'api://AzureADTokenExchange'
)

$ErrorActionPreference = 'Stop'

$roles = @(
    'Azure Service Deploy Release Management Contributor'
    'Contributor'
    'AcrPush'
)

function Invoke-Az {
    $out = & az @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed: $out" }
    $out
}

$fic = @($FederatedCredentialName, $FederatedIssuer, $FederatedSubject) | Where-Object { $_ }
if ($fic.Count -notin 0, 3) {
    throw 'Specify all of -FederatedCredentialName, -FederatedIssuer and -FederatedSubject, or none of them.'
}

Invoke-Az account set --subscription $SubscriptionId | Out-Null

$mi = & az identity show --name $IdentityName --resource-group $ResourceGroup --output json 2>$null
if ($LASTEXITCODE -eq 0 -and $mi) {
    Write-Host "Managed identity '$IdentityName' already exists; reusing it."
    $mi = $mi | ConvertFrom-Json
} elseif ($PSCmdlet.ShouldProcess($IdentityName, 'Create user-assigned managed identity')) {
    $mi = Invoke-Az identity create --name $IdentityName --resource-group $ResourceGroup --location $Location --output json | ConvertFrom-Json
}
if (-not $mi) { return }

$acrId = (Invoke-Az acr show --name $RegistryName --resource-group $RegistryResourceGroup --query id --output tsv).Trim()

foreach ($role in $roles) {
    $existing = Invoke-Az role assignment list --assignee $mi.principalId --scope $acrId --role $role --query 'length(@)' --output tsv
    if ([int]$existing -gt 0) {
        Write-Host "Role '$role' already assigned."
        continue
    }
    if ($PSCmdlet.ShouldProcess($acrId, "Assign '$role' to $IdentityName")) {
        Invoke-Az role assignment create --assignee-object-id $mi.principalId --assignee-principal-type ServicePrincipal `
            --role $role --scope $acrId --output none | Out-Null
        Write-Host "Assigned '$role'."
    }
}

if ($fic.Count -eq 3) {
    $existingFic = & az identity federated-credential show --name $FederatedCredentialName --identity-name $IdentityName --resource-group $ResourceGroup --output json 2>$null
    if ($LASTEXITCODE -eq 0 -and $existingFic) {
        Write-Host "Federated credential '$FederatedCredentialName' already exists."
    } elseif ($PSCmdlet.ShouldProcess($IdentityName, "Add federated credential '$FederatedCredentialName'")) {
        Invoke-Az identity federated-credential create --name $FederatedCredentialName --identity-name $IdentityName `
            --resource-group $ResourceGroup --issuer $FederatedIssuer --subject $FederatedSubject --audiences $FederatedAudience --output none | Out-Null
        Write-Host "Added federated credential '$FederatedCredentialName'."
    }
}

[pscustomobject]@{
    IdentityName = $mi.name
    ClientId     = $mi.clientId
    PrincipalId  = $mi.principalId
    ResourceId   = $mi.id
    AcrId        = $acrId
    Roles        = $roles -join ', '
}
