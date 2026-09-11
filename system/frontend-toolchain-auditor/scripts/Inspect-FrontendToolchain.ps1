[CmdletBinding()]
param(
    [switch]$Offline,
    [string]$OutputPath
)

$ErrorActionPreference = 'Continue'
$toolRows = [System.Collections.Generic.List[object]]::new()
$globalRows = [System.Collections.Generic.List[object]]::new()
$managerRows = [System.Collections.Generic.List[object]]::new()
$notes = [System.Collections.Generic.List[string]]::new()

function Invoke-VersionCommand {
    param([string]$Name, [string[]]$Arguments = @('--version'))
    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) { return $null }
    try {
        $value = (& $command.Source @Arguments 2>$null | Select-Object -First 1).ToString().Trim()
        [pscustomobject]@{ Version = $value; Path = $command.Source }
    } catch {
        $notes.Add("$Name was found, but its version command failed: $($_.Exception.Message)")
        $null
    }
}

function Add-Tool {
    param([string]$Name, [string]$Command, [string[]]$Arguments = @('--version'))
    $result = Invoke-VersionCommand -Name $Command -Arguments $Arguments
    $toolRows.Add([pscustomobject]@{
        Tool = $Name
        Installed = if ($result) { 'Yes' } else { 'No' }
        Version = if ($result) { $result.Version } else { '-' }
        Path = if ($result) { $result.Path } else { '-' }
        Latest = if ($Offline) { 'Not checked (offline)' } else { 'Pending' }
        Status = if ($result) { 'Installed' } else { 'Not installed' }
    })
}

Add-Tool 'Node.js' 'node'
Add-Tool 'Git' 'git'
Add-Tool 'npm' 'npm'
Add-Tool 'pnpm' 'pnpm'
Add-Tool 'Yarn' 'yarn'
Add-Tool 'Bun' 'bun'
Add-Tool 'Corepack' 'corepack'
Add-Tool 'nvm-windows' 'nvm' @('version')
Add-Tool 'fnm' 'fnm'
Add-Tool 'Volta' 'volta'

$nvm = Get-Command nvm -ErrorAction SilentlyContinue
if ($nvm) {
    try {
        $versions = (& $nvm.Source list 2>$null | Out-String).Trim()
        $managerRows.Add([pscustomobject]@{ Manager = 'nvm-windows'; CanSwitch = 'Yes'; Versions = ($versions -replace '\r?\n', '; ') })
    } catch { $notes.Add("nvm-windows version listing failed: $($_.Exception.Message)") }
}
$fnm = Get-Command fnm -ErrorAction SilentlyContinue
if ($fnm) {
    try {
        $versions = (& $fnm.Source list 2>$null | Out-String).Trim()
        $managerRows.Add([pscustomobject]@{ Manager = 'fnm'; CanSwitch = 'Yes'; Versions = ($versions -replace '\r?\n', '; ') })
    } catch { $notes.Add("fnm version listing failed: $($_.Exception.Message)") }
}
$volta = Get-Command volta -ErrorAction SilentlyContinue
if ($volta) {
    try {
        $versions = (& $volta.Source list node 2>$null | Out-String).Trim()
        $managerRows.Add([pscustomobject]@{ Manager = 'Volta'; CanSwitch = 'Yes'; Versions = ($versions -replace '\r?\n', '; ') })
    } catch { $notes.Add("Volta version listing failed: $($_.Exception.Message)") }
}

if (-not $Offline) {
    try {
        $nodeReleases = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 15
        $latestCurrent = $nodeReleases | Select-Object -First 1
        $latestLts = $nodeReleases | Where-Object { $_.lts } | Select-Object -First 1
        $nodeRow = $toolRows | Where-Object Tool -eq 'Node.js'
        $nodeRow.Latest = "LTS $($latestLts.version); Current $($latestCurrent.version)"
        if ($nodeRow.Installed -eq 'Yes') { $nodeRow.Status = 'Compare with latest LTS' }
    } catch {
        $notes.Add("The official Node.js version query failed: $($_.Exception.Message)")
    }

    try {
        $gitRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers @{ 'User-Agent' = 'frontend-toolchain-auditor' } -TimeoutSec 15
        $gitRow = $toolRows | Where-Object Tool -eq 'Git'
        $gitRow.Latest = $gitRelease.tag_name
        if ($gitRow.Installed -eq 'Yes') { $gitRow.Status = 'Compare with latest Git for Windows release' }
    } catch {
        $notes.Add("The Git for Windows stable release query failed: $($_.Exception.Message)")
    }

    foreach ($packageTool in @('npm', 'pnpm', 'yarn')) {
        $row = $toolRows | Where-Object Tool -eq $(if ($packageTool -eq 'yarn') { 'Yarn' } else { $packageTool })
        if ($row.Installed -ne 'Yes') { continue }
        try {
            $latest = (& $packageTool view $packageTool version 2>$null | Select-Object -First 1).ToString().Trim()
            if ($latest) { $row.Latest = $latest; $row.Status = if ($row.Version.TrimStart('v') -eq $latest.TrimStart('v')) { 'Current' } else { 'Version differs' } }
        } catch {
            $notes.Add("The stable $packageTool version query failed: $($_.Exception.Message)")
        }
    }

    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if ($npm) {
        try {
            $outdatedText = (& $npm.Source outdated -g --json 2>$null | Out-String).Trim()
            if ($outdatedText) {
                $outdated = $outdatedText | ConvertFrom-Json
                $outdated.PSObject.Properties | ForEach-Object {
                    $globalRows.Add([pscustomobject]@{ Manager = 'npm'; Package = $_.Name; Current = $_.Value.current; Latest = $_.Value.latest; Status = 'Update available' })
                }
            }
        } catch {
            $notes.Add("The npm global dependency update query failed: $($_.Exception.Message)")
        }
    }
}

foreach ($manager in @('npm', 'pnpm')) {
    $command = Get-Command $manager -ErrorAction SilentlyContinue
    if (-not $command) { continue }
    try {
        $listArgs = if ($manager -eq 'npm') { @('list', '-g', '--depth=0', '--json') } else { @('list', '-g', '--depth=0', '--json') }
        $jsonText = (& $command.Source @listArgs 2>$null | Out-String).Trim()
        if (-not $jsonText) { continue }
        $data = $jsonText | ConvertFrom-Json
        $dependencies = if ($manager -eq 'pnpm' -and $data -is [array]) { $data[0].dependencies } else { $data.dependencies }
        if ($dependencies) {
            $dependencies.PSObject.Properties | ForEach-Object {
                if (-not ($globalRows | Where-Object { $_.Manager -eq $manager -and $_.Package -eq $($_.Name) })) {
                    $globalRows.Add([pscustomobject]@{ Manager = $manager; Package = $_.Name; Current = $_.Value.version; Latest = if ($Offline) { 'Not checked' } else { '-' }; Status = 'Installed' })
                }
            }
        }
    } catch {
        $notes.Add("The $manager global dependency list failed: $($_.Exception.Message)")
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Frontend Toolchain Audit')
$lines.Add('')
$lines.Add("- Checked at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
$lines.Add("- Online checks: $(if ($Offline) { 'No' } else { 'Yes' })")
$lines.Add('')
$lines.Add('## Tool versions')
$lines.Add('')
$lines.Add('| Tool | Installed | Current version | Latest stable | Status | Path |')
$lines.Add('| --- | --- | --- | --- | --- | --- |')
foreach ($row in $toolRows) {
    $lines.Add("| $($row.Tool) | $($row.Installed) | $($row.Version) | $($row.Latest) | $($row.Status) | $($row.Path) |")
}
$lines.Add('')
$lines.Add('## Node version switching')
$lines.Add('')
if ($managerRows.Count -eq 0) {
    $lines.Add('No working Node version manager was found; switching capability is unconfirmed.')
} else {
    $lines.Add('| Manager | Can switch | Installed/current versions |')
    $lines.Add('| --- | --- | --- |')
    foreach ($row in $managerRows) {
        $lines.Add("| $($row.Manager) | $($row.CanSwitch) | $($row.Versions) |")
    }
}
$lines.Add('')
$lines.Add('## Global Node dependencies')
$lines.Add('')
if ($globalRows.Count -eq 0) {
    $lines.Add('No global dependencies were found, or the package manager was unavailable.')
} else {
    $lines.Add('| Manager | Package | Current | Latest stable | Status |')
    $lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($row in $globalRows | Sort-Object Manager, Package) {
        $lines.Add("| $($row.Manager) | $($row.Package) | $($row.Current) | $($row.Latest) | $($row.Status) |")
    }
}
$lines.Add('')
$lines.Add('## Unconfirmed items')
$lines.Add('')
if ($notes.Count -eq 0) { $lines.Add('None.') } else { foreach ($note in $notes) { $lines.Add("- $note") } }
$lines.Add('')
$lines.Add('> Read-only audit: no install, update, uninstall, or configuration change was performed.')

$report = $lines -join [Environment]::NewLine
if ($OutputPath) {
    $resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    [System.IO.File]::WriteAllText($resolvedOutput, $report, [System.Text.UTF8Encoding]::new($false))
    Write-Output "Report saved: $resolvedOutput"
} else {
    Write-Output $report
}
