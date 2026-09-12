---
name: git-commit-push
description: 整理当前 Git 工作区改动，生成“emoji + 类型 + 中文标题 + 编号改动点”的规范提交信息，提交全部改动并推送当前分支；最后汇报耗时、文件数、增删行数、完整提交内容和目标分支。用户要求“提交代码”“提交并推送”“执行 pnpm run commit”或“帮我 commit/push”时使用。
platform: all
tags:
  - git
  - commit
  - push
  - workflow
---

# Git 提交与推送

从首次检查仓库开始计时，到 push 完成或流程终止时停止。只处理 Git 提交与推送，不修改业务文件。

## 安全边界

禁止删除、覆盖、还原、格式化或改写用户文件。不得为通过提交而修复代码、清理生成物、调整配置，或运行会改写文件的格式化/修复命令。禁止使用 `git checkout --`、`git restore`、`git reset --hard`、`git clean` 等会改变工作区内容的命令。

允许的写操作仅限 Git 暂存和提交元数据，以及仓库外可安全清理的临时提交信息文件。发现不应提交、无法提交或校验失败的内容时，保留现场并停止说明。

## 提交规范

先识别仓库自己的贡献文档、提交模板、package scripts、commitlint/Husky 配置和近期提交历史。项目规则优先；仅在项目未规定时使用本 Skill 默认格式：

```text
<emoji> <type>: <简洁明确的中文标题>

1. 第一个具体改动点
2. 第二个具体改动点
```

正文按业务结果整理为 1–5 个连续编号改动点，简单改动不强行凑数，禁止第 6 点。标题描述整体结果，正文必须覆盖此次纳入提交的全部改动，不能用文件清单或“修改代码”等空泛表述。

| 类型 | Emoji | 适用范围 |
| --- | --- | --- |
| `feature` | ✨️ | 功能开发、迭代 |
| `fix` | 🐞 | BUG 修复 |
| `style` | 🎨 | 样式调整 |
| `refactor` | 🌀 | 重构 |
| `test` | ⚡️ | 添加、修改测试 |
| `build` | 📦️ | 架构、依赖调整 |
| `perf` | 🧪 | 性能优化 |
| `ci` | 🌐 | CI 配置、脚本变更 |
| `docs` | 📝 | 文档更新 |
| `chore` | 🔧 | 杂项 |
| `revert` | ⏪️ | 回滚 |

混合改动以核心目的为准。项目不使用 emoji 或采用其他类型体系时，不添加本 Skill 的前缀。

## 执行流程

### 1. 检查仓库和风险

读取提交相关规则后，只读检查当前分支、上游、工作区以及未推送提交：

```powershell
git branch --show-current
git status --branch --short
git status --porcelain
git rev-list --count '@{push}..HEAD'
git log '@{push}..HEAD' --oneline --no-decorate
```

无上游导致后两条失败时继续，稍后通过 `git push -u` 建立上游。若处于 detached HEAD、存在未解决冲突或无法可靠判断状态，停止并说明。

若已有未推送提交，列出并询问是否先 push。选择先 push 时，push 失败即停止本次新提交；选择跳过时继续。工作区干净时，完成已有提交的 push 后结束，不创建空提交。

检查环境变量文件、密钥、token、证书、个人数据和明显不应入库的生成物；存在疑似敏感内容时，不得暂存、提交或推送。

### 2. 理解全部改动

同时检查已暂存、未暂存和未跟踪文件：

```powershell
git diff --stat HEAD
git diff --name-status HEAD
git diff HEAD
git ls-files --others --exclude-standard
```

按需读取未跟踪文本文件。因为后续会执行 `git add .`，提交信息必须覆盖全部改动。若存在明显无关且无法合理合并的多组改动，先请用户确认范围。

### 3. 生成并预告提交信息

按“项目规则优先，默认规则补充”生成最终 message。提交前核对编号连续且不超过 5 点，并在 commentary 中展示完整 message 后直接继续；用户要求提交或推送已构成授权，无需二次确认。

### 4. 提交

优先使用项目提供的 `pnpm run commit` 入口，以兼容项目 hook 和校验。按入口提示选择类型，输入不含 emoji/type 前缀的标题与正文并确认。

项目没有该入口时，执行 `git add .`，把完整 message 写入仓库外的临时文件，再执行：

```powershell
git commit -F <临时文件>
```

完成后清理临时文件。不要在命令行中转义拼接多行 message，不得绕过 hook。提交失败时保留全部用户文件和当前工作区状态；如需恢复本流程造成的暂存变化，只能操作 Git 索引，且必须证明不会改变工作区文件。

### 5. 推送

提交成功后记录真实哈希和 message：

```powershell
git rev-parse HEAD
git log -1 --format=%B
git push
```

当前分支无上游时，使用已确认的分支名：

```powershell
git push -u origin <branch>
```

Push 失败不得撤销已成功的 commit，应保留现场并报告错误与处理建议。

### 6. 统计并汇报

```powershell
git show --numstat --format= HEAD
git show --shortstat --format= HEAD
git status --branch --short
```

最终用中文简洁汇报总耗时、分支、commit 短哈希、文件数、文本增删行数、二进制文件情况、完整提交 message、提交后的工作区状态和 push 结果。只有 push 确实成功时，才能表述“已提交并推送到 `<branch>` 分支”。若仅推送已有提交，明确说明未创建新提交，并省略本次提交统计。
