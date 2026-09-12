# aurora-skills

个人 Agent Skill 仓库。收集日常反复用到的能力，打包成可被 AI Agent 自动发现、自动加载的 skill。

每个 skill = 一个目录 + 一份 `SKILL.md`（YAML frontmatter 描述触发条件，正文描述执行步骤），可选带 `scripts/`、`references/`、`assets/`。

---

## 目录结构

一级目录按**使用场景**划分（不按技术栈，否则类目会爆炸）：

| 目录 | 说明 | 典型内容 |
| --- | --- | --- |
| [`development/`](sort-skills/development) | 软件开发 | 语言速查、框架约定、调试排错、重构、代码审查、测试 |
| [`devops/`](sort-skills/devops) | 工程与运维 | 环境搭建、构建、CI/CD、Docker、K8s、Git 工作流、部署发布、监控告警 |
| [`data-ai/`](sort-skills/data-ai) | 数据与 AI | 数据清洗、分析、可视化、爬虫、LLM 应用、Prompt 工程 |
| [`office-docs/`](sort-skills/office-docs) | 文档与办公 | Word / Excel / PPT / PDF / Markdown 互转、报告图表、会议纪要 |
| [`media/`](sort-skills/media) | 媒体创作 | 图片、视频、音频、3D、设计稿处理 |
| [`system/`](sort-skills/system) | 系统与本机 | 磁盘、进程、网络、性能诊断、系统配置（Windows / Linux） |
| [`research/`](sort-skills/research) | 信息研究 | 搜索检索、竞品调研、资讯聚合、事实核查、技术选型 |
| [`productivity/`](sort-skills/productivity) | 效率与事务 | 日程、待办、笔记、邮件、文件整理、个人自动化 |
| [`learning/`](sort-skills/learning) | 学习成长 | 备考计划、知识梳理、读书笔记、学习路线 |
| [`finance/`](sort-skills/finance) | 金融与商业 | 投资分析、记账、财报解读、商业/咨询分析框架 |

> 以上 10 个分类目录统一收在 **`sort-skills/`** 下。仓库是唯一数据源；推荐通过 `scripts/link-skills.ps1` 将 Skill 以 junction 形式映射到 `~/.agents/skills/` 或其他 Agent 目录。

**所有 skill 都放在 `sort-skills/<类>/` 下**（上表的 10 个分类）；`_templates/` 仍是顶层模板源，不在 `sort-skills` 内。

以下目录是仓库基础设施；只有项目级维护 Skill 会被同步，但不会进入业务站点：

```
_templates/    skill 模板，新建 skill 时复制
_archive/      废弃但有参考价值的 skill，不参与安装与检索
scripts/       仓库工具：安装、校验、站点生成
site/          浏览站点（GitHub Pages 源目录）
.agents/skills/maintain-aurora-skills/  项目级仓库维护 Skill，不进入业务分类和浏览站点
```

## 快速开始

```powershell
# 默认用 junction 同步到 ~/.agents/skills，源文件修改即时生效
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\link-skills.ps1

# 一次同步到多个 Agent 目录
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\link-skills.ps1 `
  -TargetDir "$env:USERPROFILE\.agents\skills","$env:USERPROFILE\.workbuddy\skills"

# 预览将要执行的清理；确认后去掉 -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\link-skills.ps1 -Prune -WhatIf

# 兼容复制模式
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Force
```

也可以复制 `scripts/skill-targets.example.json` 为被 Git 忽略的 `scripts/skill-targets.json`，保存本机的多个目标目录。

```bash
# macOS / Linux：默认软链到 ~/.agents/skills，加 -c 改为复制
./scripts/install.sh
./scripts/install.sh -t ~/.claude/skills
```

安装脚本会递归查找所有 `SKILL.md`，**平铺**安装到目标目录（忽略源目录层级），因此分类可以随意调整而不影响加载。

## 在线浏览

站点：https://yeyongzhi.github.io/aurora-skills/

左侧是分类目录树，右侧是文件内容，右上角一键复制原文，`#` 锚点可直接分享到某个文件，搜索框支持匹配文件名、标签和正文内容（按 `/` 聚焦）。

```bash
python -m pip install -r requirements.txt
python scripts/build-site.py          # 生成 site/data/skills.js
python scripts/build-site.py --check  # 仅检查生成数据是否过期
```

浏览器读不到仓库目录结构，所以需要这一步把内容聚合成数据文件。生成后本地双击 `site/index.html` 同样能看——数据通过 `<script>` 注入而非 `fetch`，`file://` 下不会被 CORS 拦掉。

每次 push 到 `master`，[`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml) 会自动重新生成并部署，线上始终是最新的。**首次使用需到仓库 Settings → Pages → Source 选择 GitHub Actions。**

## 新建一个 skill

```bash
cp -r _templates/skill-template sort-skills/<类>/<skill-name>
# 然后编辑 sort-skills/<类>/<skill-name>/SKILL.md
```

规范要点：

1. **目录名 = `name` 字段**，必须一致，全小写连字符（`kebab-case`）。
2. **一个 skill 只归一个类**。归属有歧义时，看"用户会用什么话提出这个需求"，而不是看它用了什么技术。交叉属性写进 `tags`。
3. **`description` 决定能不能被触发**，这是整个 skill 最关键的字段。写清楚「做什么」+「什么时候用」，中英文触发词都带上。
4. 超过 300 行的内容拆到 `references/`，脚本放 `scripts/`，不要让 `SKILL.md` 变成大杂烩。

完整规范见 [`_templates/skill-template/SKILL.md`](_templates/skill-template/SKILL.md)。

## 维护

```bash
python -m pip install -r requirements.txt
python scripts/lint-skills.py --strict
python -m unittest discover -s tests -v
python scripts/build-site.py
python scripts/build-site.py --check
```

校验器会同时检查 `sort-skills/` 与 `.agents/skills/`；生成器只发布业务 Skill 和模板。生成结果具有确定性，内容没有变化时不会重写文件。

分级规则：单个分类下超过 8 个 skill 时，再拆二级目录（如 `sort-skills/development/languages/`）。**不要提前分层**——空目录会劝退自己。

## 归类决策

拿不准放哪时，按这个顺序问：

1. 它是**产出物**还是**过程**？产出文档 → `office-docs`；产出代码/改代码 → `development`。
2. 用户描述需求时说的是**业务意图**还是**工具名**？说工具名（"帮我配 Docker"）→ 按工具所在的运维场景；说意图（"我想知道该买哪只"）→ `finance`。
3. 还是拿不准 → 放 `productivity`，并在 `tags` 里补线索。放错位置可以 `git mv`，不要卡住不动。
