# _templates · 模板

新建 skill 的起点。这里是仓库的基础设施，**不会被安装脚本部署**。

## 用法

```bash
cp -r _templates/skill-template <分类>/<skill-name>
```

然后按 `SKILL.md` 里的注释逐项填写，重点是 `description` —— Agent 靠它判断什么时候该加载这个 skill，写不好就不会被触发。

## 目录约定

- 目录名 = frontmatter 里的 `name`，kebab-case，两者必须一致（`lint-skills.py` 会校验）
- 可执行脚本放 `scripts/`，参考文档放 `references/`，示例数据放 `assets/`
- `SKILL.md` 保持精简，长内容拆到同目录的其他文件里按需读取
