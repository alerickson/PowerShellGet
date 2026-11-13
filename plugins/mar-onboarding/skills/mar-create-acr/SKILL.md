---
name: mar-create-acr
description: Create the Azure Container Registry (ACR) that a PowerShell module is published to before it is onboarded to MAR. Use when the user needs a new ACR for MAR/PSResource publishing.
---

# Create an ACR for MAR publishing

The PSResource is published to this ACR, and MAR then syndicates it from there.

## Prerequisites
- Azure CLI (`az`), signed in with `az login`. Use the correct tenant (Corp or AME).
- Permission to create resources in the target subscription and resource group.

## Steps
1. Confirm the subscription, resource group, ACR name, location, and SKU with the user. Check MAR's onboarding docs for SKU requirements. The script defaults to `Premium`.
2. Run the helper script. It's idempotent: it reuses an existing resource group or ACR.

   ```powershell
   ./scripts/New-MarAcr.ps1 -SubscriptionId <sub> -ResourceGroup <rg> -RegistryName <acr> -Location <region> [-Sku Premium]
   ```

3. Record the `LoginServer` it outputs, for example `myregistry.azurecr.io`. Later phases need it.

## Done when
`az acr show -n <acr>` returns the registry and the user has its login server and resource ID.
