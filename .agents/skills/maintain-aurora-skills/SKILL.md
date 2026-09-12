---
name: maintain-aurora-skills
description: 维护 aurora-skills 个人 Skill 仓库，包括新建、修改、移动、校验和同步 Skill。用户要求维护这个仓库、创建或调整 Skill、更新 Skill 分类，或把仓库 Skill 同步到 Agent 用户目录时使用；普通业务任务不使用本 Skill。
metadata:
  platform: windows
  tags:
    - skill-authoring
    - repository-maintenance
    - synchronization
  version: 1.0.0
---

# 维护 aurora-skills

把仓库作为唯一数据源维护，并在成功新增、修改、移动或删除 Skill 后，将仓库中的 Skill 链接同步到用户指定的 Agent Skill 目录。

## 仓库约定

- 日常使用的 Skill 位于 `sort-skills/<category>/<skill-name>/`。
- 本仓库的维护 Skill 位于 `.agents/skills/maintain-aurora-skills/`，不属于业务分类，也不进入浏览站点。
- 每个 Skill 必须使用独立目录，目录名与 frontmatter 的 `name` 完全一致，并采用 kebab-case。
- 仓库是真源；用户目录中的 junction 只是入口，不在那里直接修改 Skill。
- `_templates/skill-template/` 是新 Skill 的起点；`_archive/`、`site/` 和 `scripts/` 不是 Skill 分类。

## 维护流程

1. 开始前检查 `git status --short`，保留用户已有改动，不覆盖无关文件。
2. 新建 Skill 时，先根据用户需求确定分类和名称，再从 `_templates/skill-template/` 创建目录并填写内容。修改或移动 Skill 时，先检查相关引用和脚本路径。
3. 完成内容变更后，在仓库根目录运行：

   ```powershell
   python -m pip install -r requirements.txt
   python scripts/lint-skills.py --strict
   python -m unittest discover -s tests -v
   python scripts/build-site.py
   python scripts/build-site.py --check
   ```

4. 校验成功后执行同步。优先使用用户明确指定的目标目录：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\link-skills.ps1 -TargetDir "C:\path\to\agent\skills"
   ```

   用户未指定时，脚本默认同步到 `~/.agents/skills`；也可以在被 Git 忽略的 `scripts/skill-targets.json` 中配置多个目标。清理失效链接必须显式传入 `-Prune`，执行前优先用 `-WhatIf` 预览。

5. 汇报变更的 Skill、校验结果、实际同步目标以及创建/更新/跳过的链接。除非用户明确要求，不提交、不推送，也不发布站点。

## 同步语义

- `link-skills.ps1` 使用 Windows directory junction，不复制文件；源文件修改会即时反映到所有目标目录。
- 新增、移动或删除 Skill 后必须重新运行脚本，以创建新链接、更新目标或清理属于本仓库的失效链接。
- 只修改已链接 Skill 的文件时，链接内容已即时更新；仍运行一次同步脚本以验证映射完整性。
- 遇到同名 Skill、目标位置存在真实目录或非本仓库链接时停止覆盖该项并报告，不擅自删除用户内容。

## 安全边界

- 删除或覆盖既有 Skill 前确认它确实属于当前请求。
- 同步清理只能移除指向本仓库且源目录已经不存在的 junction，不删除目标目录中的普通文件夹。
- 不把密钥、账号信息或本机私有配置写入 Skill、站点数据或 Git 历史。
- 用户只要求评估或审查时保持只读，不执行同步或其他写操作。
