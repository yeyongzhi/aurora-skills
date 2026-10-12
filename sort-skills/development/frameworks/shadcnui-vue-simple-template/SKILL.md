---
name: shadcnui-vue-simple-template
description: 创建可直接运行的 Vue 3 + TypeScript + Vite 基础项目，配置 Pinia、Vue Router、Tailwind CSS 和 shadcn-vue，预装常用 UI 组件，并完成类型检查、构建、启动和页面访问验证。用户要求新建 Vue/shadcn-vue 模板、脚手架或基础项目时使用；不用于改造已有业务项目。
platform: all
tags:
  - vue
  - vite
  - typescript
  - shadcn-vue
  - tailwindcss
  - pinia
  - vue-router
metadata:
  short-description: 创建并验证 Vue shadcn-vue 模板
---

# Shadcn Vue 简易模板

创建一个最小、完整、可验证的 Vue 3 SPA 模板。默认使用 Composition API、`<script setup lang="ts">`、Pinia、Vue Router、Tailwind CSS 和 shadcn-vue；不擅自增加业务功能、请求库、测试框架或其他依赖。

## 开始前

- 使用用户指定的目标目录；未指定时，在当前工作区创建语义明确的新目录。
- 目标目录非空时先检查内容，不覆盖或删除已有文件。存在冲突且无法安全合并时，请用户指定新目录或合并范围。
- 确认 Node.js 与 pnpm 可用。依赖使用执行时 registry 的稳定版本，不选择 `next`、`beta`、`rc` 等预发布标签。
- 执行前核对 shadcn-vue 与 Tailwind CSS 的当前官方 Vite 安装文档。CLI、包名或配置方式变化时以当前官方文档为准。

## 技术与结构约定

- 使用 Vue 3、TypeScript、Vite、Vue Router、Pinia、Tailwind CSS 和 shadcn-vue。
- 组件使用 Composition API 和 `<script setup lang="ts">`；SFC 顺序为 script、template、必要时 scoped style。
- `App.vue` 只负责应用外壳和 `<RouterView />`，路由页面负责组合功能区块。
- Pinia 使用 setup store；源状态保持最小，派生值使用 `computed`，副作用才使用 watcher。
- 配置 `@/* -> ./src/*`；TypeScript 与 Vite 中的别名必须一致。
- 优先使用包管理器和 CLI 生成 lockfile、shadcn 配置及组件源码，不手写伪造生成结果。

最小结构至少包括：

```text
index.html
.gitignore
package.json
pnpm-lock.yaml
vite.config.ts
tsconfig.json
tsconfig.app.json
tsconfig.node.json
components.json
src/
  App.vue
  main.ts
  style.css
  lib/utils.ts
  router/index.ts
  stores/counter.ts
  views/HomeView.vue
  components/ui/
```

## UI 组件强制规范

此规范适用于模板示例及基于模板继续开发的所有业务页面，必须严格遵循，不能将其降级为“优先使用”的建议。

- 所有有对应 shadcn-vue 组件的 UI 控件必须从 `@/components/ui/` 导入并使用；允许业务组件封装或组合这些组件。
- 禁止在业务页面、业务组件中直接使用原生 `button`、`input`、`textarea`、`select`、`option`、`dialog` 等交互控件，也禁止用 `div`、CSS 或其他 UI 库手写替代已有 shadcn-vue 组件。该限制不针对 CLI 生成的 `components/ui/` 内部实现。
- 文本输入使用 `Input` / `Textarea`，按钮使用 `Button`，选项选择使用 `Select`，禁止使用保留浏览器原生选择交互的 `NativeSelect`；需要搜索选择时采用官方 Combobox 方案。复选、单选和开关分别使用 `Checkbox`、`RadioGroup`、`Switch`。
- 日期选择必须使用[官方 Date Picker 方案](https://www.shadcn-vue.com/docs/components/date-picker)，通过 `Popover` 与 `Calendar` 组合；日期范围使用 `RangeCalendar` 与官方范围选择方案。禁止使用原生 `input type="date"`、`datetime-local`、`month`、`week` 或浏览器默认日期弹窗。
- 弹窗、确认框、菜单、提示、标签页、表格和分页等，使用对应的 `Dialog`、`AlertDialog`、`DropdownMenu`、`Tooltip`、`Tabs`、`Table`、`Pagination` 等组件。组件尚未安装时先用当前官方 CLI 添加，不能因为缺少组件而退回原生实现。
- 普通布局与语义内容可使用 `div`、`section`、`main`、标题、段落、`form` 等 HTML 元素，Tailwind CSS 用于布局和样式；不要把这些元素伪装成已有库组件的替代控件。
- 官方没有对应组件或组合方案时，先核对官方文档并说明缺口，取得用户明确同意后再采用自定义控件或其他方案；不得自行放宽上述要求。
- 将本节规则写入生成项目的根目录 `AGENTS.md`；已有文件时合并规则并保留原内容，让后续业务开发持续遵循同一约束。

## 创建流程

### 1. 初始化项目

优先使用当前稳定版官方 Vite Vue TypeScript 模板，再安装依赖：

```powershell
pnpm create vite@latest <project-name> --template vue-ts
Set-Location <project-name>
pnpm install
pnpm add vue-router@latest pinia@latest
```

若用户要求从空目录构建，也要提供 `dev`、`build`、`preview` scripts，并让 `build` 包含类型检查，例如 `vue-tsc -b && vite build`。

`.gitignore` 至少覆盖：

```gitignore
node_modules/
dist/
dist-ssr/
coverage/
*.log
.env
.env.*
!.env.example
*.local
.vscode/*
!.vscode/extensions.json
.idea/
.DS_Store
Thumbs.db
```

已有 `.gitignore` 只补缺失规则。不得忽略 `pnpm-lock.yaml`、`components.json` 或 `src/components/ui/`。

### 2. 配置应用骨架

- `main.ts` 依次注册 Pinia 与 router，再挂载应用。
- router 至少提供 `/` 首页，并按需懒加载路由页面。
- 创建一个 setup store，在首页真实读取状态并调用 action，以证明注册有效。
- 在 `tsconfig.app.json` 与 `vite.config.ts` 配置一致的 `@` 别名；不要在无必要时重复配置多个 tsconfig。
- 删除 Vite 示例内容时只删除新模板生成且已确认不再使用的文件，不能波及目标目录中的既有用户文件。

### 3. 配置 Tailwind CSS

按照当前官方 Vite 方案安装与配置。若官方仍使用 Vite 插件方案，执行：

```powershell
pnpm add tailwindcss@latest @tailwindcss/vite@latest
```

在 `vite.config.ts` 保留 Vue 插件并注册 Tailwind 插件，在全局样式入口加入：

```css
@import "tailwindcss";
```

不要混用旧版 Tailwind 初始化命令或 PostCSS 配置，除非当前官方文档明确要求。

### 4. 初始化 shadcn-vue

完成路径别名和 Tailwind 配置后执行当前官方初始化命令；通常为：

```powershell
pnpm dlx shadcn-vue@latest init
```

选择 Vite + TypeScript 配置，基础色默认使用 `Neutral`。初始化后检查 `components.json`、样式入口、别名和 `src/lib/utils.ts` 是否指向真实路径。

### 5. 安装并展示常用组件

先单独安装 Button，再安装其余组件，便于定位基础配置问题：

```powershell
pnpm dlx shadcn-vue@latest add button
pnpm dlx shadcn-vue@latest add input label card dialog dropdown-menu select table badge separator skeleton tooltip
```

当前 CLI 不支持批量参数时逐个安装。组件已存在时保留现有实现，不使用覆盖参数。按页面需求追加组件；例如日期选择先添加 `popover`、`calendar`，范围选择再添加 `range-calendar`，组件名及额外依赖以当前官方文档为准。不要预装所有组件，但所有实际使用的控件必须符合 UI 组件强制规范。

首页至少渲染 `Button`、`Card`、`Input` 和 `Badge`，并提供一个触发 Pinia action 的交互。页面只需清晰证明别名、样式、组件、状态和路由工作正常。

## 验证

依次执行：

```powershell
pnpm run build
pnpm run dev -- --host 127.0.0.1
```

从终端读取实际端口，请求首页并确认响应成功、无编译错误。可使用浏览器时再检查布局、组件样式和交互。检查完成后正常停止开发服务器，不遗留后台进程。

同时确认：

- `node_modules/`、`dist/` 与本地环境文件会被忽略。
- `pnpm-lock.yaml`、`components.json` 和 `src/components/ui/` 不会被忽略。
- 检查所有业务页面与业务组件的控件来源，确认没有原生选择框、日期输入或其他被禁止的替代控件；排除 `src/components/ui/` 内部实现，发现违规必须修正后再交付。
- 根目录 `AGENTS.md` 已记录 UI 组件强制规范，示例页面也严格遵循。
- 构建包含类型检查；不得通过禁用插件、删除检查或移除所需依赖掩盖错误。

安装、构建或启动失败时，读取完整错误，修正模板配置并重新验证。网络或权限受限时保留当前项目状态，准确报告失败步骤，不能声称已完成。

## 交付

简洁汇报目标目录绝对路径、核心技术栈、预装组件、`.gitignore` 合并结果，以及安装、构建、开发服务器、首页访问的各自结果和实际访问地址。未完成时说明失败原因与保留状态。
