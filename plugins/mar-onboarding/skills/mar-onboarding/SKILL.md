---
name: mar-onboarding
description: End-to-end workflow to onboard a PowerShell module to MAR (Microsoft Artifact Registry / MCR) as a PSResource, optionally syndicated to the Air-Gapped Clouds (USNat/USSec). Use for prompts like "Onboard the module X to MAR", "Publish my PowerShell module to MAR", or "Syndicate my PSResource to the AGCs".
---

# Onboard a PowerShell module to MAR as a PSResource

This skill runs the whole onboarding. Each phase has its own skill, so read that skill before you start the phase.

## 0. Gather inputs

Look in the user's prompt and repository for these values. Ask for anything that's missing in a single form:

| Input | Example | Notes |
|-------|---------|-------|
| Module name and path | `Microsoft.PowerShell.PSResourceGet`, `./out/MyModule` | The folder that contains the `.psd1`, or a built `.nupkg` |
| Azure subscription and resource group | `my-sub`, `rg-mymodule` | The subscription that will host the ACR |
| ACR name and region | `mymoduleregistry`, `westus2` | Globally unique, alphanumeric only |
| Tenant | Corp or AME | If the ACR is in AME, Ev2 needs Federated Identity Credentials |
| Syndicate to AGCs? | yes/no | Adds the `syndications` block to the MCR PR |
| Publish strategy | `manual` or `ev2` | Ev2 is recommended for production and recurring releases |

Track the phases as todos.

## 1. Create the ACR
Use the **mar-create-acr** skill. Skip this phase if the user already has an ACR.

## 2. Onboard the ACR to MAR
Use the **mar-onboard-acr** skill. It covers the PR to the MCR GitHub repository and the AGC syndication block. These addendums override MAR's own documentation:
- If the user wants AGC syndication, every module entry in the MCR PR must include the `syndications` block.
- **Ignore MAR's instructions about triggering a publish to MAR.** PSResources are published only as described in phase 3.

Publishing can't start until the MCR PR is merged and MAR onboarding is complete. When the PR is open, stop and tell the user they need to wait for it to merge before continuing.

## 3. Publish the PSResource
- Manual: use **mar-publish-manual**.
- Ev2 pipeline: use **mar-publish-ev2**.

If the module was pushed to the ACR before MAR onboarding finished, push it again to trigger syndication.

## 4. Verify
Use **mar-verify-publishing**. Check that the ACR has `<visibility tag>/psresource/<ModuleName>` with the correct version tag, and that syndication shows in the MCRFlow status portal: https://status-portal.mscr.io/

## Finish
Summarize what was created: the ACR, the MCR PR link, the publish method, the published version, and the verification results. Also list any remaining manual steps the user owns, such as PR approval, JIT approval for Ev2, or Ev2 ServiceGroup registration.
