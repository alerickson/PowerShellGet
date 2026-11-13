# MAR Onboarding plugin

This Agency, Copilot CLI, or Claude Code plugin onboards a PowerShell module to **MAR (Microsoft Artifact Registry)** as a **PSResource**. It can also syndicate the module to the Air-Gapped Clouds (USNat and USSec).

Example prompts:

> Onboard the PowerShell module in `./out/MyModule` to MAR using ACR `mymoduleacr` in subscription `<sub>`, publish with Ev2, and syndicate it to the AGCs.

> Publish MyModule 1.2.3 to MAR manually and verify it syndicated.

You can also run the slash command: `/onboard-to-mar MyModule mymoduleacr manual syndicate-agc`

## What's included

| Component | Purpose |
|-----------|---------|
| `skills/mar-onboarding` | Runs the whole workflow and starts the right skill for each phase |
| `skills/mar-create-acr` | Creates the ACR (`scripts/New-MarAcr.ps1`) |
| `skills/mar-onboard-acr` | Opens the MCR GitHub PR, applies the MAR doc addendums, and adds the AGC `syndications` block (`scripts/Get-MarSyndicationBlock.ps1`) |
| `skills/mar-publish-manual` | Publishes with `Publish-PSResource -ModulePrefix psresource` and PSResourceGet 1.2.0 or later (`scripts/Publish-PSResourceToMar.ps1`) |
| `skills/mar-publish-ev2` | Sets up the managed identity, roles, and federated identity credentials (`scripts/New-MarPublishIdentity.ps1`), resolves the Ev2 sample's TODOs, covers ServiceGroup registration, and bumps the version (`scripts/Update-Ev2BuildVersion.ps1`) |
| `skills/mar-verify-publishing` | Checks the ACR repository and tag, MCRFlow status, and webhook activity (`scripts/Test-MarPublish.ps1`) |
| `agents/mar-onboarding.md` | Specialist subagent |
| `commands/onboard-to-mar.md` | `/onboard-to-mar` slash command |

## Install

This repository is a plugin marketplace (`.claude-plugin/marketplace.json` at the repository root).

```text
# Agency / Claude Code
/plugin marketplace add alerickson/PowerShellGet
/plugin install mar-onboarding@powershellget-plugins

# GitHub Copilot CLI
copilot plugin marketplace add alerickson/PowerShellGet
copilot plugin install mar-onboarding@powershellget-plugins
```

To test a local checkout, point the marketplace at the folder instead, for example `/plugin marketplace add C:\code\PowerShellGet`.

## Prompt template for onboarding teams

After you install the plugin, start a new Agency session and send the template below. Replace each `<...>` with your own value. If you leave a value out, the agent asks for it.

```text
Onboard my PowerShell module to MAR as a PSResource.

- Module name: <MyModule>
- Module path: <C:\path\to\MyModule or .\out\MyModule.1.0.0.nupkg>
- Azure subscription: <subscription id or name>
- Resource group: <rg-name>
- ACR: <existing ACR name, or "create new ACR named X">
- Region: <westus2>
- Tenant: <Corp | AME>
- Syndicate to Air-Gapped Clouds (USNat/USSec): <yes | no>
- Publish method: <manual | ev2>
- MCR GitHub repo / MAR onboarding doc: <link>
- (Ev2 only) Ev2 sample pipeline location: <link or path>
- (Ev2 only) Managed identity name: <mi-name>
- (Ev2 only) Ev2 ServiceGroup name: <name>
- (Ev2 only) ADO variable group name: <name>

Confirm with me before creating any Azure resources or publishing.
```

Short version:

```text
Onboard my PowerShell module <MyModule> at <path> to MAR using ACR <acrname>, publish <manually | with Ev2>, and <syndicate | don't syndicate> to the AGCs.
```

Slash command:

```text
/onboard-to-mar <MyModule> <acrname> <manual|ev2> syndicate-agc
```

### What to expect
The agent creates or reuses the ACR, then opens the MCR PR. It pauses until the PR is merged. After that, it publishes the module and verifies the result.

Some steps still need a person:
- Approving the MCR PR
- Approving the Ev2 release through JIT with AME credentials
- Registering the Ev2 ServiceGroup
- Signing `Run.ps1`

### Test without touching Azure
Add this sentence to any prompt to see the full plan without creating or publishing anything:

```text
This is a test. Show me each command you would run, but do not create any Azure resources or publish anything.
```

## Prerequisites
- PowerShell 7 or later
- Azure CLI (`az`), signed in to the correct tenant (Corp or AME)
- `gh` CLI, for opening the MCR PR
- Microsoft corpnet access for the MAR docs, the MCR repository, and https://status-portal.mscr.io/

## Things the plugin can't do for you
- Merge or approve the MCR PR
- Approve the Ev2 release with JIT and AME credentials
- Register the Ev2 ServiceGroup and ServicePresence, if your process requires a portal or a human
- Sign `Run.ps1`

When it reaches one of these steps, the agent stops and tells you what to do.
