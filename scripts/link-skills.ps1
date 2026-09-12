#Requires -Version 5.1
<#
.SYNOPSIS
    Synchronize repository skills to one or more Agent skill directories.

.DESCRIPTION
    Uses directory junctions by default, with an optional copy compatibility mode.
    Targets may be passed with -TargetDir or stored in scripts/skill-targets.json.
    Pruning is opt-in and only removes junctions that point inside this repository.

.EXAMPLE
    .\link-skills.ps1
.EXAMPLE
    .\link-skills.ps1 -TargetDir "$env:USERPROFILE\.agents\skills", "$env:USERPROFILE\.workbuddy\skills"
.EXAMPLE
    .\link-skills.ps1 -TargetDir "D:\agent-skills" -Prune -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [string]$RepoRoot,
    [Alias('WorkbuddySkills')]
    [string[]]$TargetDir,
    [ValidateSet('Junction', 'Copy')]
    [string]$Mode = 'Junction',
    [switch]$Force,
    [switch]$Prune,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    if ($PSScriptRoot) {
        $RepoRoot = Split-Path -Parent $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }
    else {
        $RepoRoot = $PWD.Path
    }
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$sortSkills = Join-Path $RepoRoot 'sort-skills'
$configPath = Join-Path $RepoRoot 'scripts\skill-targets.json'

function Write-Status {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    if (-not $Json) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Resolve-FullPath {
    param([string]$Path, [string]$BasePath)
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if (-not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-Path $BasePath $expanded
    }
    return [IO.Path]::GetFullPath($expanded).TrimEnd('\', '/')
}

function Test-PathInside {
    param([string]$Child, [string]$Parent)
    $childFull = [IO.Path]::GetFullPath($Child).TrimEnd('\', '/')
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)
}

function Get-LinkTarget {
    param([IO.FileSystemInfo]$Item)
    if (-not ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        return $null
    }
    $target = @($Item.Target)[0]
    if (-not $target) {
        return $null
    }
    if (-not [IO.Path]::IsPathRooted($target)) {
        $target = Join-Path $Item.Parent.FullName $target
    }
    return [IO.Path]::GetFullPath($target).TrimEnd('\', '/')
}

if (-not (Test-Path -LiteralPath $sortSkills -PathType Container)) {
    throw "sort-skills not found at $sortSkills"
}

if (-not $TargetDir -or $TargetDir.Count -eq 0) {
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        $config = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json
        $TargetDir = @($config.targets)
    }
    if (-not $TargetDir -or $TargetDir.Count -eq 0) {
        $TargetDir = @((Join-Path $env:USERPROFILE '.agents\skills'))
    }
}

$targets = @(
    $TargetDir |
        Where-Object { $_ } |
        ForEach-Object { Resolve-FullPath -Path $_ -BasePath $RepoRoot } |
        Sort-Object -Unique
)

$skillFiles = @(Get-ChildItem -Path $sortSkills -Recurse -Filter 'SKILL.md' -File -Force)
$maintenanceSkill = Join-Path $RepoRoot '.agents\skills\maintain-aurora-skills\SKILL.md'
if (Test-Path -LiteralPath $maintenanceSkill -PathType Leaf) {
    $skillFiles += Get-Item -LiteralPath $maintenanceSkill -Force
}
if ($skillFiles.Count -eq 0) {
    throw 'No SKILL.md files were found.'
}

$skills = @{}
foreach ($file in $skillFiles) {
    $name = $file.Directory.Name
    $source = [IO.Path]::GetFullPath($file.Directory.FullName).TrimEnd('\', '/')
    if ($skills.ContainsKey($name)) {
        throw "Duplicate skill name '$name': '$source' and '$($skills[$name])'"
    }
    $skills[$name] = $source
}

$results = [Collections.Generic.List[object]]::new()
$expectedSources = @{}
foreach ($source in $skills.Values) {
    $expectedSources[$source.ToLowerInvariant()] = $true
}

foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target)) {
        if ($PSCmdlet.ShouldProcess($target, 'Create target skill directory')) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
    }
    if (-not (Test-Path -LiteralPath $target)) {
        continue
    }

    Write-Status "==> Synchronizing $($skills.Count) skills to $target ($Mode)" Cyan

    foreach ($name in ($skills.Keys | Sort-Object)) {
        $source = $skills[$name]
        $destination = Join-Path $target $name
        $existing = Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue

        if ($Mode -eq 'Junction') {
            if ($existing) {
                $linkTarget = Get-LinkTarget -Item $existing
                if ($linkTarget -and $linkTarget.Equals($source, [StringComparison]::OrdinalIgnoreCase)) {
                    $results.Add([pscustomobject]@{ Target=$target; Skill=$name; Status='unchanged'; Path=$destination })
                    Write-Status "  = $name" DarkGray
                    continue
                }
                $ownedLink = $linkTarget -and (Test-PathInside -Child $linkTarget -Parent $RepoRoot)
                if (-not $Force -and -not $ownedLink) {
                    $results.Add([pscustomobject]@{ Target=$target; Skill=$name; Status='conflict'; Path=$destination })
                    Write-Status "  ! $name (existing path is not managed by this repository)" Yellow
                    continue
                }
                if ($PSCmdlet.ShouldProcess($destination, 'Replace existing skill entry')) {
                    if ($linkTarget) {
                        [IO.Directory]::Delete($destination, $false)
                    }
                    else {
                        Remove-Item -LiteralPath $destination -Recurse -Force
                    }
                }
            }
            if (-not (Test-Path -LiteralPath $destination) -and $PSCmdlet.ShouldProcess($destination, "Create junction to $source")) {
                New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
                $results.Add([pscustomobject]@{ Target=$target; Skill=$name; Status='linked'; Path=$destination })
                Write-Status "  + $name" Green
            }
        }
        else {
            if ($existing -and -not $Force) {
                $results.Add([pscustomobject]@{ Target=$target; Skill=$name; Status='skipped'; Path=$destination })
                Write-Status "  = $name (exists; use -Force to refresh copy)" Yellow
                continue
            }
            if ($existing -and $PSCmdlet.ShouldProcess($destination, 'Replace copied skill')) {
                $linkTarget = Get-LinkTarget -Item $existing
                if ($linkTarget) {
                    [IO.Directory]::Delete($destination, $false)
                }
                else {
                    Remove-Item -LiteralPath $destination -Recurse -Force
                }
            }
            if (-not (Test-Path -LiteralPath $destination) -and $PSCmdlet.ShouldProcess($destination, "Copy skill from $source")) {
                Copy-Item -LiteralPath $source -Destination $destination -Recurse
                $results.Add([pscustomobject]@{ Target=$target; Skill=$name; Status='copied'; Path=$destination })
                Write-Status "  + $name" Green
            }
        }
    }

    if ($Prune) {
        foreach ($item in Get-ChildItem -LiteralPath $target -Force) {
            $linkTarget = Get-LinkTarget -Item $item
            if (-not $linkTarget -or -not (Test-PathInside -Child $linkTarget -Parent $RepoRoot)) {
                continue
            }
            if ($expectedSources.ContainsKey($linkTarget.ToLowerInvariant())) {
                continue
            }
            if ($PSCmdlet.ShouldProcess($item.FullName, "Remove stale repository junction to $linkTarget")) {
                [IO.Directory]::Delete($item.FullName, $false)
                $results.Add([pscustomobject]@{ Target=$target; Skill=$item.Name; Status='pruned'; Path=$item.FullName })
                Write-Status "  - $($item.Name)" Red
            }
        }
    }
}

if ($Json) {
    ConvertTo-Json -InputObject @($results) -Depth 4
}
else {
    $summary = $results | Group-Object Status | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }
    Write-Host ""
    Write-Host ("Done: " + ($summary -join ', ')) -ForegroundColor Cyan
}
