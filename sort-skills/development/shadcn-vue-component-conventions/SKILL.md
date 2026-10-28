---
name: shadcn-vue-component-conventions
description: 在采用 shadcn-vue 的 Vue 前端项目中，根据业务场景选择和组合统一的 UI 组件。用户要求使用 shadcn-vue 开发、调整或审查页面、表单、导航、反馈和交互时使用；不用于强制其他技术栈迁移组件库。
metadata:
  platform: all
  tags:
    - vue
    - shadcn-vue
    - ui-components
    - frontend
  version: 0.1.0
---

# shadcn-vue 组件使用规范

为采用 shadcn-vue 的 Vue 项目提供场景到组件的选择规则，使交互、外观与无障碍行为保持一致。官网组件目录：<https://www.shadcn-vue.com/docs/components>。

## 使用范围和优先级

- 用户明确要求 shadcn-vue，或项目已经采用它时，开发和修改涉及的界面按以下映射选用组件。用户明确要求和项目已有约定优先；不要借此改造无关页面或将其他组件库项目迁移到 shadcn-vue。
- 先检查项目已有的组件、封装、别名及版本；优先复用项目中的 shadcn-vue 组件和业务封装。对应组件缺失时，参照官网当前文档和项目包管理器添加；不要覆盖项目已有定制。无法添加时说明限制，采用符合项目约定的可访问替代方案。
- 匹配组件存在时，业务界面使用组件而不是自己仿制同类控件；组件内部实现、语义性布局元素以及组件库没有覆盖的特殊交互不受此限制。
- 场景映射是本技能的项目约定，不代表官网规定每种场景只有一种实现。根据交互语义、移动端空间和项目实际组件版本选择；需要时查询官网对应组件的用法和无障碍要求。

## 场景与组件

| 场景 | 使用组件与选择依据 |
| --- | --- |
| 提交、保存、取消、图标操作 | `Button`；通过 variant、size 区分主次和危险操作，图标按钮提供可访问名称。 |
| 单行文本、搜索、多行文本、数字 | 分别使用 `Input`、`Textarea`、`Number Field`；搜索框按需组合 `Input Group`。 |
| 表单字段、标签、提示与错误 | 使用项目版本提供的 `Field` 或 `Form` 组合与 `Label`；关联标签、描述和错误，校验状态同时传给控件。 |
| 开关、多个独立选项、互斥选项 | 即时启停用 `Switch`；可多选用 `Checkbox`；少量互斥选项用 `Radio Group`。 |
| 下拉选择与可搜索选择 | 固定选项用 `Select`；需要搜索或筛选选项用 `Combobox`；平台原生选择有明确需求时可用 `Native Select`。 |
| 数值范围、日期、验证码、标签 | 分别使用 `Slider`、`Date Picker`/`Calendar`、`Input OTP`、`Tags Input`；按实际数据语义组合。 |
| 同级内容切换、路径、分页 | 分别使用 `Tabs`、`Breadcrumb`、`Pagination`；页面导航和侧栏按需用 `Navigation Menu`、`Sidebar`。 |
| 操作菜单、右键菜单、命令搜索 | 分别使用 `Dropdown Menu`、`Context Menu`、`Command`。不要把菜单和表单选择混为一谈。 |
| 常规弹窗、侧边详情、移动端抽屉 | 分别考虑 `Dialog`、`Sheet`、`Drawer`；需要明确确认的重要操作用 `Alert Dialog`。提供标题、焦点管理和可关闭方式。 |
| 简短悬停提示、悬浮内容 | 简短说明用 `Tooltip`；需要交互的浮层用 `Popover`；补充预览可用 `Hover Card`。不要把必要信息只放在悬停提示中。 |
| 页内提示、操作结果、加载状态 | 持续可见提示用 `Alert`；短暂操作反馈用 `Sonner`；内容占位用 `Skeleton`，进行中用 `Spinner`，可量化进度用 `Progress`。 |
| 空状态、状态标记、内容分组 | 分别使用 `Empty`、`Badge`、`Card`；分隔内容用 `Separator`，按需用 `Accordion` 或 `Collapsible` 展开内容。 |
| 数据展示 | 简单表格用 `Table`；需要排序、筛选、分页等能力时参考 `Data Table` 组合；头像用 `Avatar` 并提供 fallback。 |

## 实施检查

1. 确认当前任务涉及的交互场景，按映射选择组件并查看项目现有实现；组件名称或 API 因版本不同而变化时，以项目实际代码及对应版本文档为准。
2. 使用组件的现有变体和主题语义变量，保持项目样式一致；通过组合组件实现业务行为，保留键盘操作、焦点、标签和状态反馈。
3. 验证涉及的主要交互、窄屏布局和必要的类型检查或构建。遇到组件缺失、与既有约定冲突或需要新增依赖时，在结果中说明实际选择。
