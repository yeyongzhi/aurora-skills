#Requires -Version 5.1
<#
.SYNOPSIS
    Compatibility wrapper for link-skills.ps1 copy or junction modes.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$TargetDir = @((Join-Path $env:USERPROFILE '.agents\skills')),
    [switch]$Link,
    [switch]$Force,
    [switch]$Prune,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$mode = if ($Link) { 'Junction' } else { 'Copy' }
$sync = Join-Path $PSScriptRoot 'link-skills.ps1'
& $sync -TargetDir $TargetDir -Mode $mode -Force:$Force -Prune:$Prune -Json:$Json -WhatIf:$WhatIfPreference
