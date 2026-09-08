---
name: disk-space-analyzer
description: 扫描 Windows 本机磁盘（C 盘、D 盘等全部盘符），统计每个盘的总容量与剩余可用空间，列出各盘下占用空间最大的文件夹/文件（按体积降序），并检测常见缓存、临时、系统占用目录给出分级清理建议，最终生成一个可离线打开的 HTML 报告。Whenever the user mentions 磁盘空间、清理 C 盘 / D 盘、disk space、磁盘占用、哪些文件占地方大、电脑空间不足、storage analysis、清理建议、find large files/folders、释放空间、或想知道某个盘里什么东西最占空间 —— 即使没有明确说"生成报告"，也应使用本 skill。仅适用于 Windows。
platform: windows
tags:
  - disk
  - cleanup
  - powershell
  - report
---

# 磁盘空间分析器（disk-space-analyzer）

扫描本机磁盘并产出一份 HTML 报告，回答三个问题：当前有哪些盘、每个盘剩多少空间、每个盘里什么最占地方，并附带可清理项的提示。**本 skill 只统计与提示，绝不删除任何文件。**

## 适用环境

仅限 **Windows**，使用 PowerShell（5.1 或 7+ 均可），无需安装任何第三方依赖。报告为单个 HTML 文件，可双击离线打开。

## 运行方式

skill 目录下有两个文件：
- `scripts/Analyze-DiskSpace.ps1` —— 扫描脚本（采集数据）
- `scripts/report-template.html` —— 报告模板（脚本会把数据注入其中）

两者必须放在同一目录。默认执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Analyze-DiskSpace.ps1"
```

脚本会扫描全部固定磁盘，在**桌面**生成 `disk-report-<时间戳>.html` 并自动打开。

### 常用参数

| 参数 | 作用 | 示例 |
| --- | --- | --- |
| `-Drives` | 只扫指定盘符 | `-Drives C:,D:` |
| `-OutputPath` | 自定义报告输出路径 | `-OutputPath D:\report.html` |
| `-IncludeRemovable` | 同时扫描可移动盘（U 盘 / 移动硬盘） | `-IncludeRemovable` |
| `-NoOpen` | 生成后不自动打开 | `-NoOpen` |

例如只分析 D 盘并指定输出位置：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Analyze-DiskSpace.ps1" -Drives D: -OutputPath D:\d-report.html
```

## 执行注意事项

- **以管理员身份运行 PowerShell** 可减少「无权限」目录，统计更完整；否则部分系统目录会被标记为「无权限」，不影响其余结果。
- 首次扫描整盘（尤其 C 盘）可能需要 **1–5 分钟**，取决于文件数量；脚本会显示进度条。
- 体积统计为**顶层目录/文件**粒度（每个盘根目录下的一级项目），这样既快又能定位到最该清理的大块。需要继续下钻时，可用 `-Drives` 单独跑某个盘，或人工进入报告里指出的大目录查看。
- 如果用户的 PowerShell 执行策略受限，命令中的 `-ExecutionPolicy Bypass` 已临时绕过，不会修改系统设置。

## 报告内容（生成后向用户说明）

报告分三部分：
1. **磁盘概览** —— 每个盘的容量、已用/可用、占用百分比（>90% 标红、>75% 标橙）。
2. **各盘占用明细** —— 顶层文件夹/文件按体积**降序**排列，越大越靠前，带占本盘百分比；命中清理/系统模式的项会显示彩色标签。
3. **清理建议** —— 临时文件、浏览器缓存、npm/pnpm/pip 等包管理器缓存、Windows 更新缓存、回收站、Windows.old、休眠/页面文件等，按风险分三级：
   - 🟢 **可清理（safe）**：可放心清理。
   - 🟠 **谨慎（caution）**：需人工确认后再处理。
   - 🔴 **系统（system）**：请勿手动删除，应通过系统功能调整。

## 安全红线

本 skill **不执行任何删除操作**。当用户问"能不能帮我删掉"时：
- 解释每一类的正确清理方式（如休眠文件用 `powercfg -h off`、包缓存用对应命令、回收站手动清空等），优先引导用户使用 Windows 内置「存储感知 / 磁盘清理」。
- 对「系统」级项目明确劝阻直接删除。
- 删除前提醒用户确认文件用途，避免误删。
