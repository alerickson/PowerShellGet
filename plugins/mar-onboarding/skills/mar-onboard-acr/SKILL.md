---
name: mar-onboard-acr
description: Onboard an ACR to MAR by opening a PR to the MCR GitHub repository, with the optional syndication block that replicates a PowerShell module to the Air-Gapped Clouds (USNat/USSec). Use when onboarding an ACR to MAR/MCR or enabling AGC syndication for a PSResource.
---

# Onboard the ACR to MAR, with optional AGC syndication

## Addendums to MAR's own onboarding docs (these take priority)
1. If the module should be replicated to the MARs in the Air-Gapped Clouds (USNat/USSec), add the syndication block below to **every** module entry in the PR to the MCR GitHub repository.
2. **Ignore MAR's instructions about triggering a publish to MAR.** PSResources are published with `Publish-PSResource` or the Ev2 pipeline. See the `mar-publish-manual` and `mar-publish-ev2` skills.

## Steps
1. Ask the user for the MAR onboarding documentation link and the MCR GitHub repository if you don't have them. Follow that documentation for the PR structure, such as file location, owners, and repository mapping. Don't invent fields.
2. Clone or fork the MCR repository and create a branch. Add or update the entry or entries for the module's ACR repositories. The ACR repository path for a PSResource is `<visibility tag>/psresource/<ModuleName>`; see `Publish-PSResource -ModulePrefix`.
3. If the user wants AGC syndication, add this block to each module entry, indented to match that entry:

   ```yaml
   syndications:
     - type: cloud
       destinations:
         - usnat
         - ussec
       tags:
         - source: /^(0|[1-9]\d*)(\.(0|[1-9]\d*)){0,3}$/
   ```

   To print it at a specific indentation, run:

   ```powershell
   ./scripts/Get-MarSyndicationBlock.ps1 -Indent 4
   ```

   To check that every module entry in the edited file has it, run:

   ```powershell
   ./scripts/Get-MarSyndicationBlock.ps1 -ValidatePath <path-to-edited-yaml> -ExpectedEntryCount <number of module entries>
   ```

4. Open the PR (with `gh pr create` if the repository is on GitHub) and give the user the link.
5. Tell the user that publishing can't start until the PR is merged and MAR onboarding is complete.

## Done when
The MCR PR is open (or merged), every entry has the syndication block if AGC syndication was requested, and the user has the PR link.
