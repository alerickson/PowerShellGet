---
name: mar-publish-manual
description: Manually publish a PowerShell module to an MAR-onboarded ACR as a PSResource with Publish-PSResource (PSResourceGet 1.2.0 or later) and the 'psresource' module prefix. Use for one-off or first-time publishes to MAR.
---

# Publish a PSResource to MAR manually

## Prerequisites
- The ACR is fully onboarded to MAR (the MCR PR is merged).
- PowerShell 7 or later.
- You're signed in to Azure with push rights on the ACR: `az login` or `Connect-AzAccount`. PSResourceGet authenticates to the ACR with your Azure credentials.

## Steps
1. Confirm the module path (a folder that contains the `.psd1`, or a `.nupkg`) and the ACR name with the user.
2. Run the helper script. It installs or updates `Microsoft.PowerShell.PSResourceGet` to at least version 1.2.0, registers the ACR as a PSResource repository, and publishes with `-ModulePrefix`:

   ```powershell
   ./scripts/Publish-PSResourceToMar.ps1 -Path <module folder or .nupkg> -RegistryName <acr> [-ModulePrefix psresource] [-WhatIf]
   ```

   It runs the equivalent of:

   ```powershell
   Install-PSResource Microsoft.PowerShell.PSResourceGet -Version '[1.2.0,)'
   Register-PSResourceRepository -Name <acr> -Uri https://<acr>.azurecr.io -ApiVersion ContainerRegistry
   Publish-PSResource -Path <module> -Repository <acr> -ModulePrefix 'psresource'
   ```

3. **If the module was pushed to the ACR before MAR onboarding finished, push it again** (use `-Force` on the helper) to trigger syndication.
4. Continue with the `mar-verify-publishing` skill.

## Notes
- `-ModulePrefix` sets the ACR repository path to `<prefix>/<modulename>` (lowercase). MAR drops the prefix when it syndicates. Use the prefix that your MCR entry maps, for example `psresource` or `public/psresource`.
- Each publish needs a new module version. ACR won't accept a version tag that already exists.
