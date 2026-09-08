#Requires -Version 5.1
<#
.SYNOPSIS
    把仓库里的 skill 安装到 Agent 的 skills 目录。

.DESCRIPTION
    递归查找所有 SKILL.md，将所在目录平铺安装到目标目录（忽略源目录层级）。
    默认复制；-Link 改为符号链接（需要管理员权限或开启开发者模式）。
    排除 _archive、_templates、scripts 及隐藏目录。

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Link
    .\install.ps1 -TargetDir "$env:USERPROFILE\.claude\skills" -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TargetDir = (Join-Path $env:USERPROFILE '.workbuddy\skills'),
    [switch]$Link,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$skip = @('.git', '_archive', '_templates', 'scripts', '.workbuddy', 'node_modules')

$skills = Get-ChildItem -Path $repoRoot -Recurse -Filter 'SKILL.md' -File | Where-Object {
    $rel = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
    $parts = $rel -split '[\\/]'
    -not ($parts | Where-Object { $skip -contains $_ -or $_ -like '.*' })
}

if (-not $skills) {
    Write-Warning "未在 $repoRoot 下找到任何 SKILL.md"
    exit 0
}

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Host "已创建目录 $TargetDir"
}

$ok = 0; $skipped = 0; $failed = 0

foreach ($file in $skills) {
    $name = $file.Directory.Name
    $dest = Join-Path $TargetDir $name

    if (Test-Path $dest) {
        if ($Force) {
            Remove-Item $dest -Recurse -Force
        }
        else {
            Write-Host "  跳过 $name（已存在，用 -Force 覆盖）" -ForegroundColor Yellow
            $skipped++
            continue
        }
    }

    try {
        if ($Link) {
            $null = New-Item -ItemType SymbolicLink -Path $dest -Target $file.Directory.FullName
        }
        else {
            Copy-Item -Path $file.Directory.FullName -Destination $dest -Recurse -Force
        }
        Write-Host "  + $name" -ForegroundColor Green
        $ok++
    }
    catch {
        Write-Host "  ! $name : $($_.Exception.Message)" -ForegroundColor Red
        if (-not $Link) { throw }
        $failed++
    }
}

Write-Host ""
Write-Host "完成：安装 $ok，跳过 $skipped，失败 $failed -> $TargetDir"
if ($failed -gt 0 -and $Link) {
    Write-Host "提示：符号链接需要管理员权限或 Windows 开发者模式，也可不带 -Link 改用复制。" -ForegroundColor Yellow
}
