---
name: mar-publish-ev2
description: Set up an Ev2 Managed SDP pipeline that publishes a PowerShell module's .nupkg to an MAR-onboarded ACR as a PSResource. Covers the managed identity and role assignments, federated identity credentials for AME, resolving the sample pipeline's TODOs, ServiceGroup/ServicePresence registration, and bumping buildVer.txt. Use for production or recurring MAR releases.
---

# Publish a PSResource to MAR with an Ev2 pipeline

## 1. Create the managed identity and grant it access to the ACR
Run the helper script. It creates the user-assigned managed identity if it doesn't exist and assigns these roles on the ACR: **Azure Service Deploy Release Management Contributor**, **Contributor**, and **AcrPush**. If the ACR is in **AME**, pass the federated identity credential values from the Ev2 Federated Identity Credentials documentation; ask the user for them if needed.

```powershell
./scripts/New-MarPublishIdentity.ps1 -SubscriptionId <sub> -ResourceGroup <rg> -IdentityName <mi-name> -RegistryName <acr> -Location <region> `
    [-FederatedCredentialName <name> -FederatedIssuer <issuer> -FederatedSubject <subject> [-FederatedAudience api://AzureADTokenExchange]]
```

Record the `ClientId`, `PrincipalId`, and `ResourceId` it outputs. Store them in the ADO variable group (step 3), not in source.

## 2. Bring in the sample pipeline
Ask the user where the Ev2 Managed SDP sample is (it's the PSResourceGet sample with `PSResourceGet-Release-Official-Azure.yml`, `release-publish-mar.yml`, and the `EV2Specs` folder). Copy it into the user's repository and keep the layout:

- `PSResourceGet-Release-Official-Azure.yml` is the release pipeline. It sets the **source pipeline** that builds the `.nupkg` (in the sample, `PSResourceGetBuild` produces `microsoft.powershell.psresourceget.<version>.nupkg`) and calls `release-publish-mar.yml`.
- `release-publish-mar.yml` has two stages:
  - **PrepForEV2** downloads the `.nupkg`, gets the module name and version from its file name, and replaces placeholder values in the Ev2 spec files (`ServiceModel.json`, `*.Rollout.json`, `RolloutSpec.json`, and so on) with values from the ADO variable group.
  - **Prod_Release** runs the Ev2 task with `EndpointProviderType` and `ApprovalServiceEnvironment`, so the rollout waits for approval.
- `EV2Specs/ServiceGroupRoot/Shell/Run/Run.ps1` is the Shell extension script that publishes to ACR/MAR. **It must be signed.**

## 3. Resolve every `# TODO`
Find them with:

```powershell
Get-ChildItem -Recurse -Include *.yml,*.yaml,*.json,*.ps1,*.txt | Select-String '# ?TODO'
```

For each TODO, fill in the source pipeline name, the artifact or `.nupkg` name pattern, the module name, the variable group name, and so on. Put general-access values (subscription ID, resource group, managed identity client ID and name, ACR name and URI, support emails) in an **ADO library variable group** that PrepForEV2 substitutes at runtime, especially if the repository is public. Never commit these values.

## 4. Register the ServiceGroup and ServicePresence (Managed SDP)
Follow the Managed SDP Ev2 registration instructions, and ask the user for the link if you don't have it. Then:

- Use the chosen `$ServiceGroupName` for `serviceGroup` in `ServiceModel.json`, `name` in `RolloutSpec.json`, and `name` in `ServiceGroupSpecification.json`.
- When registering the ServicePresence `$location`, use the region where the ACR is.

## 5. Bump buildVer.txt on every release
Ev2 won't redeploy an artifact version it has already registered. If the version doesn't change, Ev2 rolls out the old artifact. Bump it before each new module version:

```powershell
./scripts/Update-Ev2BuildVersion.ps1 -Path <path-to>/buildVer.txt            # increments the last segment
./scripts/Update-Ev2BuildVersion.ps1 -Path <path-to>/buildVer.txt -Version 1.2.0.0
```

## 6. Run the release
Queue the release pipeline. At **Prod_Release**, the approver must:
- Use **AME** credentials, because the target resources are in the AME tenant.
- Get elevated access through **JIT** before approving.

Wrong-tenant credentials or missing permissions cause a `caller has insufficient permissions` failure.

Then continue with the `mar-verify-publishing` skill.
