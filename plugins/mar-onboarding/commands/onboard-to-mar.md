---
description: Onboard a PowerShell module to MAR as a PSResource (end to end)
argument-hint: <module name or path> [acr name] [manual|ev2] [syndicate-agc]
---

Onboard the PowerShell module described by these arguments to MAR as a PSResource: $ARGUMENTS

Use the `mar-onboarding` skill to drive the work. It runs these phases in order and delegates each to its own skill:
create the ACR, onboard it to MAR (with AGC syndication if requested), publish the PSResource (manually or with Ev2), and verify it.
