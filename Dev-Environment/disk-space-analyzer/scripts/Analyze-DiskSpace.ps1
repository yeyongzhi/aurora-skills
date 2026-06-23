<#
.SYNOPSIS
    扫描本机磁盘，统计各盘容量与顶层目录/文件体积，识别可清理项，生成 HTML 报告。

.DESCRIPTION
    1. 枚举所有固定磁盘（可选包含可移动盘），读取总容量 / 可用空间。
    2. 对每个盘扫描根目录下的顶层文件夹与文件，递归计算体积，按大小降序。
    3. 检测常见缓存 / 临时 / 系统占用目录，给出风险分级的清理建议。
    4. 将数据注入 report-template.html，输出可离线打开的 HTML 报告。

    脚本只做统计与提示，绝不删除任何文件。

.PARAMETER Drives
    指定要扫描的盘符（如 'C:','D:'）。默认扫描全部固定磁盘。

.PARAMETER OutputPath
    报告输出路径。默认为桌面 disk-report-<时间戳>.html。

.PARAMETER IncludeRemovable
    同时扫描可移动磁盘（U 盘 / 移动硬盘）。

.PARAMETER NoOpen
    生成后不自动打开报告。

.EXAMPLE
    .\Analyze-DiskSpace.ps1

.EXAMPLE
    .\Analyze-DiskSpace.ps1 -Drives C: -OutputPath C:\report.html
#>
[CmdletBinding()]
param(
    [string[]]$Drives,
    [string]$OutputPath,
    [switch]$IncludeRemovable,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# ---------- 工具函数 ----------

# 递归计算文件夹体积；返回 @{ Bytes; Denied }（Denied 表示遇到无权限子项）
function Get-FolderSize {
    param([string]$Path)
    $errs = $null
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -Force `
                -ErrorAction SilentlyContinue -ErrorVariable +errs |
            Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    $denied = $false
    if ($errs) {
        foreach ($e in $errs) {
            if ($e.Exception -is [System.UnauthorizedAccessException]) { $denied = $true; break }
        }
    }
    [pscustomobject]@{ Bytes = [int64]$sum; Denied = $denied }
}

# 根据顶层项目名称给出风险分类（用于明细表的彩色标签）
function Get-ItemCategory {
    param([string]$Name, [bool]$IsFile)
    switch -Regex ($Name) {
        '^\$Recycle\.Bin$'                 { return 'safe' }
        '^Windows\.old$'                   { return 'caution' }
        '^(hiberfil|pagefile|swapfile)\.sys$' { return 'system' }
        '^(Windows|System Volume Information|Recovery|\$WinREAgent|Config\.Msi)$' { return 'system' }
        default                            { return $null }
    }
}

# 安全地取得某路径体积（不存在则返回 $null）
function Try-PathSize {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    if ($item.PSIsContainer) { return (Get-FolderSize -Path $Path).Bytes }
    else { return [int64]$item.Length }
}

# ---------- 选择磁盘 ----------

# DriveType: 2=可移动, 3=固定
$typeFilter = if ($IncludeRemovable) { 'DriveType=2 OR DriveType=3' } else { 'DriveType=3' }
$logical = Get-CimInstance -ClassName Win32_LogicalDisk -Filter $typeFilter -ErrorAction Stop

if ($Drives) {
    $want = $Drives | ForEach-Object { $_.TrimEnd('\').TrimEnd(':').ToUpper() + ':' }
    $logical = $logical | Where-Object { $want -contains $_.DeviceID.ToUpper() }
}
if (-not $logical) { throw '未找到符合条件的磁盘。' }

# ---------- 逐盘扫描 ----------

$driveResults = @()
foreach ($disk in $logical) {
    $letter = $disk.DeviceID            # 如 'C:'
    $root   = "$letter\"
    Write-Host "[*] 正在扫描 $letter ($([math]::Round($disk.Size/1GB,1)) GB) ..." -ForegroundColor Cyan

    $items = @()
    $scanError = $null
    try {
        $top = Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue
        $count = ($top | Measure-Object).Count
        $i = 0
        foreach ($entry in $top) {
            $i++
            Write-Progress -Activity "扫描 $letter" -Status $entry.Name `
                -PercentComplete (($i / [math]::Max($count,1)) * 100)

            $isFile = -not $entry.PSIsContainer
            if ($isFile) {
                $bytes  = [int64]$entry.Length
                $denied = $false
            } else {
                $r = Get-FolderSize -Path $entry.FullName
                $bytes  = $r.Bytes
                $denied = $r.Denied
            }
            $items += [pscustomobject]@{
                name         = $entry.Name
                path         = $entry.FullName
                bytes        = $bytes
                type         = if ($isFile) { 'file' } else { 'folder' }
                category     = Get-ItemCategory -Name $entry.Name -IsFile $isFile
                accessDenied = $denied
            }
        }
        Write-Progress -Activity "扫描 $letter" -Completed
    } catch {
        $scanError = $_.Exception.Message
    }

    $items = $items | Sort-Object -Property bytes -Descending

    $driveResults += [pscustomobject]@{
        letter     = $letter
        label      = $disk.VolumeName
        fileSystem = $disk.FileSystem
        totalBytes = [int64]$disk.Size
        freeBytes  = [int64]$disk.FreeSpace
        usedBytes  = [int64]($disk.Size - $disk.FreeSpace)
        items      = @($items)
        scanError  = $scanError
    }
}

# ---------- 清理建议 ----------

Write-Host "[*] 检测常见可清理目录 ..." -ForegroundColor Cyan
$sysDrive = $env:SystemDrive   # 通常 'C:'

# 候选清单：名称 / 路径 / 风险(safe|caution|system) / 建议
$candidates = @(
    @{ name='Windows 临时文件';        path="$env:WINDIR\Temp";                                   risk='safe';
       advice='系统与程序产生的临时文件，可直接清理，或使用「磁盘清理 / 存储感知」处理。' }
    @{ name='当前用户临时文件';        path="$env:TEMP";                                          risk='safe';
       advice='当前用户的临时文件，关闭相关程序后可清理。' }
    @{ name='回收站';                  path="$sysDrive\`$Recycle.Bin";                            risk='safe';
       advice='清空回收站即可释放，建议先确认无误删文件。' }
    @{ name='Windows 更新下载缓存';    path="$env:WINDIR\SoftwareDistribution\Download";          risk='caution';
       advice='已下载的更新安装包。停止 Windows Update 服务后可清空，系统会按需重新下载。' }
    @{ name='传递优化缓存';            path="$env:WINDIR\SoftwareDistribution\DeliveryOptimization"; risk='safe';
       advice='更新分发缓存，可通过「存储设置 → 临时文件」清理。' }
    @{ name='Windows.old（旧系统）';   path="$sysDrive\Windows.old";                              risk='caution';
       advice='系统升级残留的旧版本。确认无需回退后，可在「设置 → 系统 → 存储 → 临时文件」中删除。' }
    @{ name='npm 缓存';                path="$env:LOCALAPPDATA\npm-cache";                        risk='safe';
       advice='npm 包缓存，可执行 npm cache clean --force 清理，不影响已安装依赖。' }
    @{ name='pnpm store';              path="$env:LOCALAPPDATA\pnpm\store";                       risk='safe';
       advice='pnpm 全局存储，可执行 pnpm store prune 清除未被引用的包。' }
    @{ name='Yarn 缓存';               path="$env:LOCALAPPDATA\Yarn\Cache";                       risk='safe';
       advice='Yarn 包缓存，可执行 yarn cache clean 清理。' }
    @{ name='pip 缓存';                path="$env:LOCALAPPDATA\pip\Cache";                        risk='safe';
       advice='Python pip 下载缓存，可执行 pip cache purge 清理。' }
    @{ name='Chrome 缓存';             path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"; risk='safe';
       advice='浏览器缓存，清理后首次访问网站会稍慢，可在浏览器内或直接删除。' }
    @{ name='Edge 缓存';               path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"; risk='safe';
       advice='Edge 浏览器缓存，可安全清理。' }
    @{ name='缩略图 / 图标缓存';       path="$env:LOCALAPPDATA\Microsoft\Windows\Explorer";       risk='safe';
       advice='资源管理器缩略图缓存，删除后会自动重建。' }
    @{ name='休眠文件 hiberfil.sys';   path="$sysDrive\hiberfil.sys";                             risk='system';
       advice='休眠功能占用，约等于内存大小。请勿直接删除；如不使用休眠，可执行 powercfg -h off 关闭以释放。' }
    @{ name='页面文件 pagefile.sys';   path="$sysDrive\pagefile.sys";                             risk='system';
       advice='虚拟内存文件，请勿手动删除。如需调整，请在「系统属性 → 高级 → 性能 → 虚拟内存」中设置。' }
)

$cleanup = @()
foreach ($c in $candidates) {
    $size = Try-PathSize -Path $c.path
    if ($null -ne $size -and $size -gt 0) {
        $cleanup += [pscustomobject]@{
            name   = $c.name
            path   = $c.path
            bytes  = [int64]$size
            risk   = $c.risk
            advice = $c.advice
        }
    }
}
$cleanup = $cleanup | Sort-Object -Property bytes -Descending

# ---------- 组装数据并注入模板 ----------

$sw.Stop()
$payload = [pscustomobject]@{
    computerName     = $env:COMPUTERNAME
    generatedAt      = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    totalScanSeconds = [int][math]::Round($sw.Elapsed.TotalSeconds)
    drives           = @($driveResults)
    cleanup          = @($cleanup)
}
$json = $payload | ConvertTo-Json -Depth 8 -Compress
# 防止文件名中极端出现 </script> 时破坏 HTML（\/ 在 JSON 中合法）
$json = $json -replace '</script', '<\/script'

$templatePath = Join-Path $PSScriptRoot 'report-template.html'
if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "未找到报告模板：$templatePath"
}
$template = [System.IO.File]::ReadAllText($templatePath, [System.Text.Encoding]::UTF8)
# 使用字符串 .Replace（非正则），避免 JSON 中的 $ 等字符被误解析
$html = $template.Replace('/*__DISK_DATA__*/', $json)

if (-not $OutputPath) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
    $OutputPath = Join-Path $desktop "disk-report-$stamp.html"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $html, $utf8NoBom)

Write-Host ""
Write-Host "[√] 报告已生成：$OutputPath" -ForegroundColor Green
Write-Host "    扫描磁盘 $($driveResults.Count) 个，用时 $($payload.totalScanSeconds) 秒。" -ForegroundColor Green

if (-not $NoOpen) {
    Start-Process -FilePath $OutputPath | Out-Null
}
