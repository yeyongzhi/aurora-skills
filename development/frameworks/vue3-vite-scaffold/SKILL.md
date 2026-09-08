---
name: vue3-vite-scaffold
description: 一键搭建 Vue 3 + TypeScript + Vite 项目，并安装 Tailwind CSS v4、shadcn-vue 组件库、vue-router、pinia，按预设清单批量添加 shadcn-vue 组件，最后输出依赖版本清单、组件安装成功数量与总耗时。Whenever the user mentions 搭建/初始化/创建/新建 Vue 项目、vue3 项目脚手架、vue3 + vite + ts、装一下 shadcn-vue、Add shadcn-vue components、初始化前端项目模板、或要求「按我的技术栈起个项目」 —— 即使没有明说全部细节，也应使用本 skill。
platform: all
tags:
  - vue
  - vue3
  - vite
  - typescript
  - tailwindcss
  - shadcn-vue
  - pinia
  - vue-router
  - scaffold
version: 1.0.0
---

# Vue 3 + Vite 脚手架（vue3-vite-scaffold）

把「起一个 Vue 3 项目」这件事一次性做完：技术栈、样式、组件库、路由、状态管理、常用组件，最后给一份带版本号的交付清单。

## 技术栈

主技术栈 **Vue 3 + TypeScript + Vite**，全部取**当前最新稳定版**（不锁死版本号，由包管理器解析）。

| 类别 | 包 |
| --- | --- |
| 框架 | `vue`、`@vitejs/plugin-vue` |
| 构建 | `vite`、`vue-tsc`、`typescript` |
| 路由 | `vue-router` |
| 状态 | `pinia` |
| 样式 | `tailwindcss`、`@tailwindcss/vite` |
| 组件库 | `shadcn-vue`（CLI 按需注入，非运行时依赖） |

### 版本基准快照

写本 skill 时（2026-09）实测的最新稳定版，仅用于人工核对，脚本不会锁定这些数字：

| 包 | 版本 |
| --- | --- |
| vue | 3.5.42 |
| vite | 8.2.2 |
| vue-router | 5.3.1 |
| pinia | 4.0.3 |
| tailwindcss / @tailwindcss/vite | 4.3.3 |
| shadcn-vue | 2.8.2 |
| typescript | 7.0.2 |

**版本变化很快，尤其是大版本（例如 Tailwind v3 → v4 安装方式完全不同）。执行前应先核对官方文档；`scripts/scaffold.sh` 里记录的两个文档链接是权威来源。**

## 执行方式

### 一键脚本（推荐）

```bash
bash scripts/scaffold.sh <项目名> [父目录]

# 例：在当前目录下创建 ./my-app
bash scripts/scaffold.sh my-app

# 例：指定父目录
bash scripts/scaffold.sh my-app ~/code

# 例：自定义组件清单
COMPONENTS="button card dialog table" bash scripts/scaffold.sh my-app
```

脚本会依次完成：创建项目 → 安装依赖 → 配置路径别名与 Tailwind → 初始化 shadcn-vue → 批量添加组件 → 采集版本 → 打印报告（同时写入项目根目录的 `SCAFFOLD_REPORT.md`）。

### 手动分步

脚本不可用或需要逐步确认时，按此顺序执行（已在 Vue 3.5 / Vite 8 / Tailwind 4 下验证）：

```bash
# 1. 创建项目（vue-ts 模板，非交互）
pnpm create vite@latest my-app --template vue-ts
cd my-app && pnpm install

# 2. 生态依赖
pnpm add vue-router pinia

# 3. Tailwind CSS v4 —— 见 https://tailwindcss.com/docs/installation/using-vite
pnpm add tailwindcss @tailwindcss/vite
pnpm add -D @types/node
```

`vite.config.ts`：

```ts
import path from 'node:path'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

`src/style.css` 全部替换为：

```css
@import "tailwindcss";
```

`tsconfig.json` 与 `tsconfig.app.json` 都要在 `compilerOptions` 里加：

```json
{
  "baseUrl": ".",
  "paths": {
    "@/*": ["./src/*"]
  }
}
```

```bash
# 4. shadcn-vue 初始化（非交互，见 https://www.shadcn-vue.com/docs/cli）
pnpm dlx shadcn-vue@latest init -t vite -b neutral -y -d

# 5. 添加组件（-y 跳过确认，-o 覆盖同名文件）
pnpm dlx shadcn-vue@latest add button card -y -o
```

## 默认组件清单

`components.txt`，覆盖表单、反馈、导航、数据展示、布局五类。用 `COMPONENTS` 环境变量覆盖即可改。

**清单里的组件名要与当前 shadcn-vue 注册表匹配**，改名或下线会导致该组件安装失败——脚本会跳过失败项并在报告里列出，不会中断整体流程。

## 交付报告

脚本结束时输出，同时写入 `SCAFFOLD_REPORT.md`：

1. **核心依赖清单** —— 包名 + 实际安装的版本号（从 `package.json` 读，不是猜的）
2. **组件安装结果** —— 成功数 / 总数，以及失败清单
3. **总耗时** —— 秒

把这三段原样转述给用户，不要只说「装好了」。

## 注意事项

- **pnpm 被安全软件拦截时**（例如拦截 `pnpm` 命令的删除/移动行为），改用 pnpm 可执行文件的绝对路径，或退回 `npm`。脚本支持 `PM=npm` 环境变量切换包管理器。
- **`shadcn-vue init` 必须交互时**，常见原因是项目结构不符合预期（缺少 alias 或 Tailwind 配置）。先确认上面第 3 步的三个文件都改对了再重试。
- **Tailwind v4 不再需要** `tailwind.config.js` 和 PostCSS 配置，插件方式即可。看到需要 `postcss.config.js` 的教程那是 v3，别照抄。
- **组件逐个安装**而不是一次性传入全部名称：单个失败不影响其他组件，也便于统计成功数。
- 脚本全程用 `set -euo pipefail`，任一步骤失败会立即退出——这是刻意的，避免带着半损坏的项目继续。若确实要跳过某步，手动执行分步流程。
