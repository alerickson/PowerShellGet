---
name: mar-verify-publishing
description: Verify that a PSResource was published to the ACR (repository <visibility tag>/psresource/<ModuleName> with the expected version tag) and syndicated to MAR (MCRFlow status portal, ACR webhook activity). Use after publishing a PowerShell module to MAR or when troubleshooting syndication.
---

# Verify ACR publishing and MAR syndication

## 1. Check the ACR
Run:

```powershell
./scripts/Test-MarPublish.ps1 -RegistryName <acr> -ModuleName <ModuleName> [-Version <x.y.z>] [-IncludeWebhookEvents]
```

The script checks that a repository matching `*psresource/<modulename>` exists in the ACR (for example `public/psresource/mymodule`) and that the expected version tag is present. With `-IncludeWebhookEvents`, it also lists recent events for the ACR's webhooks, which helps troubleshoot syndication.

You can also check by hand in the Azure portal: go to **ACR > Repositories**, confirm that `<visibility tag>/psresource/<ModuleName>` exists, and confirm the version tag.

## 2. Check MAR syndication
Open the MCRFlow status UI at https://status-portal.mscr.io/ (Microsoft corpnet) and find the module's repository and tag. You can't check this from the CLI; ask the user to confirm what the portal shows.

## Troubleshooting
- **The repository is missing from the ACR:** the publish failed or used a different `-ModulePrefix`. Check the publish logs.
- **The repository is in the ACR but not syndicated:** check the ACR webhook activity (`-IncludeWebhookEvents`). If the module was pushed before MAR onboarding finished, publish again.
- **AGC versions are missing:** make sure the MCR entry has the `syndications` block and that the version tag matches `^(0|[1-9]\d*)(\.(0|[1-9]\d*)){0,3}$`. Prerelease tags such as `1.0.0-preview1` don't match.
- **Ev2 rolled out the old artifact:** `buildVer.txt` wasn't bumped.
